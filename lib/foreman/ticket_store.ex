defmodule Foreman.TicketStore do
  @moduledoc "Checkout-local ticket files and graph validation; no application or database required."
  alias Foreman.TicketFile

  def load(root) do
    with :ok <- readable_directory(root),
         {:ok, tickets} <- load_files(root),
         :ok <- readable_directory(root),
         :ok <- unchanged(root, tickets),
         do: {:ok, tickets}
  end

  defp load_files(root) do
    root
    |> files()
    |> Enum.reduce_while({:ok, %{}}, fn path, {:ok, tickets} ->
      with {:ok, %{type: :regular}} <- File.lstat(path),
           {:ok, text} <- File.read(path),
           {:ok, ticket} <- TicketFile.parse(text),
           true <- ticket.facts["id"] == Path.basename(path, ".md") do
        {:cont, {:ok, Map.put(tickets, ticket.facts["id"], Map.put(ticket, :source, text))}}
      else
        {:error, reason} ->
          {:halt, {:error, "#{Path.relative_to(path, root)}: #{inspect(reason)}"}}

        _ ->
          {:halt,
           {:error, "#{Path.relative_to(path, root)}: id must match filename; regular files only"}}
      end
    end)
  end

  def check(root) do
    case readable_directory(root) do
      :ok -> check_files(root)
      {:error, {:busy, reason}} -> [%{file: "tickets", reason: reason}]
      {:error, reason} -> [%{file: "tickets", reason: reason}]
    end
  end

  defp check_files(root) do
    {tickets, errors} =
      Enum.reduce(files(root), {%{}, []}, fn path, {tickets, errors} ->
        result =
          with {:ok, %{type: :regular}} <- File.lstat(path),
               {:ok, text} <- File.read(path),
               do: TicketFile.parse(text)

        case result do
          {:ok, %{facts: _} = ticket} ->
            if ticket.facts["id"] == Path.basename(path, ".md") do
              {Map.put(tickets, ticket.facts["id"], ticket), errors}
            else
              {tickets,
               errors ++
                 [%{file: Path.relative_to(path, root), reason: "id does not match filename"}]}
            end

          other ->
            {tickets,
             errors ++ [%{file: Path.relative_to(path, root), reason: parse_reason(other)}]}
        end
      end)

    errors ++ validate_graph(tickets)
  end

  def validate_graph(tickets) do
    tickets
    |> Enum.sort()
    |> Enum.flat_map(fn {id, %{facts: facts}} ->
      missing =
        [{facts["parent"], "parent"} | Enum.map(facts["blocked_by"], &{&1, "blocker"})]
        |> Enum.flat_map(fn {ref, kind} ->
          if ref && not Map.has_key?(tickets, ref), do: ["missing #{kind}: #{ref}"], else: []
        end)

      cycles =
        for key <- ["blocked_by", "parent"],
            reaches?(references(tickets, id, key), id, key, tickets, MapSet.new()),
            do: "#{key} cycle"

      epic =
        Enum.flat_map(facts["blocked_by"], fn blocker ->
          if get_in(tickets, [blocker, :facts, "type"]) == "epic" and
               ancestor?(blocker, facts["parent"], tickets, MapSet.new()),
             do: ["epic #{blocker} cannot block its own child"],
             else: []
        end)

      Enum.map(missing ++ cycles ++ epic, &%{file: "tickets/#{id}.md", reason: &1})
    end)
  end

  def next_id(prefix, parent, ids, generator \\ nil)

  def next_id(_prefix, parent, ids, _) when is_binary(parent) do
    Stream.iterate(1, &(&1 + 1)) |> Stream.map(&"#{parent}.#{&1}") |> Enum.find(&(&1 not in ids))
  end

  def next_id(prefix, nil, ids, generator) do
    generator =
      generator ||
        fn ->
          :crypto.strong_rand_bytes(4)
          |> :binary.decode_unsigned()
          |> rem(46_656)
          |> Integer.to_string(36)
          |> String.downcase()
          |> String.pad_leading(3, "0")
        end

    Stream.repeatedly(fn -> prefix <> "-" <> generator.() end) |> Enum.find(&(&1 not in ids))
  end

  def save(root, before, after_tickets) do
    with :ok <- directory_safe(root),
         {:ok, lock} <- lock_path(root),
         do: lock_and_save(root, before, after_tickets, lock)
  end

  defp lock_and_save(root, before, after_tickets, lock) do
    directory = Path.join(root, "tickets")
    File.mkdir_p!(directory)

    case File.mkdir(lock) do
      :ok ->
        try do
          save_locked(root, before, after_tickets, lock)
        after
          if File.ls!(lock) == [], do: File.rmdir!(lock)
        end

      {:error, :eexist} ->
        {:error, {:busy, "ticket writer busy (#{lock}); retry after it finishes"}}

      {:error, reason} ->
        {:error, {:io, "cannot lock tickets: #{reason}"}}
    end
  end

  defp save_locked(root, before, after_tickets, lock) do
    with :ok <- validate_all(after_tickets),
         :ok <- unchanged(root, before) do
      changed =
        Enum.filter(after_tickets, fn {id, ticket} ->
          not Map.has_key?(before, id) or
            (Map.take(ticket, [:facts, :body]) != Map.take(before[id], [:facts, :body]) and
               TicketFile.print(ticket) != before[id].source)
        end)

      removed = Map.keys(before) -- Map.keys(after_tickets)
      touched = Enum.uniq(Enum.map(changed, &elem(&1, 0)) ++ removed)
      prepared = Path.join(lock, "prepared")
      originals = Path.join(lock, "originals")
      File.mkdir!(prepared)
      File.mkdir!(originals)

      try do
        Enum.each(changed, fn {id, ticket} ->
          File.write!(Path.join(prepared, id <> ".md"), TicketFile.print(ticket), [
            :exclusive,
            :sync
          ])
        end)

        with :ok <- claim_originals(root, before, touched, originals),
             :ok <- publish(root, changed, prepared),
             :ok <- originals_unchanged(before, originals) do
          Enum.each(File.ls!(originals), &File.rm!(Path.join(originals, &1)))
          :ok
        else
          {:error, reason} ->
            restore_originals(root, originals)
            {:error, reason <> "; any unrecovered originals remain in #{originals}"}
        end
      after
        File.rm_rf!(prepared)
        if File.ls!(originals) == [], do: File.rmdir!(originals)
      end
    end
  end

  # Claim the actual directory entry before comparing it: a check followed by
  # rename-over would lose editor saves in the check/rename window. Publishing
  # with link is no-replace, so a concurrent editor's new entry always wins.
  defp claim_originals(root, before, ids, originals) do
    Enum.reduce_while(ids, :ok, fn id, :ok ->
      if Map.has_key?(before, id) do
        backup = Path.join(originals, id <> ".md")

        with :ok <- File.rename(path(root, id), backup),
             {:ok, %{type: :regular}} <- File.lstat(backup),
             {:ok, content} <- File.read(backup),
             true <- content == before[id].source do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, "tickets changed while writing #{id}"}}
        end
      else
        {:cont, :ok}
      end
    end)
  end

  defp publish(root, changed, prepared) do
    Enum.reduce_while(changed, :ok, fn {id, _}, :ok ->
      case File.ln(Path.join(prepared, id <> ".md"), path(root, id)) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt,
           {:error, "cannot publish #{id} without replacing another writer's file: #{reason}"}}
      end
    end)
  end

  defp originals_unchanged(before, originals) do
    if Enum.all?(File.ls!(originals), fn name ->
         File.read(Path.join(originals, name)) == {:ok, before[Path.rootname(name)].source}
       end),
       do: :ok,
       else: {:error, "an original changed during publication; retaining it for recovery"}
  end

  defp restore_originals(root, originals) do
    Enum.each(File.ls!(originals), fn name ->
      backup = Path.join(originals, name)

      case File.ln(backup, Path.join([root, "tickets", name])) do
        :ok -> File.rm!(backup)
        {:error, _} -> :ok
      end
    end)
  end

  defp readable_directory(root) do
    with :ok <- directory_safe(root),
         {:ok, lock} <- lock_path(root) do
      case File.lstat(lock) do
        {:error, :enoent} ->
          :ok

        _ ->
          {:error, {:busy, "ticket write in progress or recovery required; inspect #{lock}"}}
      end
    end
  end

  defp lock_path(root) do
    case System.cmd("git", ["-C", root, "rev-parse", "--path-format=absolute", "--git-dir"],
           stderr_to_stdout: true
         ) do
      {directory, 0} -> {:ok, Path.join(String.trim(directory), ".foreman-write-lock")}
      _ -> {:error, "cannot resolve checkout git dir for ticket write recovery"}
    end
  end

  defp directory_safe(root) do
    case File.lstat(Path.join(root, "tickets")) do
      {:error, :enoent} ->
        :ok

      {:ok, %{type: :directory}} ->
        case File.ls(Path.join(root, "tickets")) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, "cannot read tickets directory: #{reason}"}
        end

      _ ->
        {:error, "tickets must be a real directory, not a symlink"}
    end
  end

  defp validate_all(tickets) do
    case Enum.find_value(tickets, fn {id, ticket} ->
           case TicketFile.validate(ticket.facts) do
             :ok -> if id != ticket.facts["id"], do: "id does not match filename"
             {:error, reason} -> reason
           end
         end) do
      nil ->
        case validate_graph(tickets) do
          [] -> :ok
          [error | _] -> {:error, "#{error.file}: #{error.reason}"}
        end

      reason ->
        {:error, reason}
    end
  end

  defp unchanged(root, before) do
    expected = Enum.sort(Map.keys(before))
    actual = Enum.map(files(root), &Path.basename(&1, ".md")) |> Enum.sort()

    if expected == actual and
         Enum.all?(before, fn {id, ticket} ->
           File.read(path(root, id)) == {:ok, ticket.source} and
             match?({:ok, %{type: :regular}}, File.lstat(path(root, id)))
         end), do: :ok, else: {:error, "tickets changed since read; retry (no files written)"}
  end

  defp references(tickets, id, key) do
    case get_in(tickets, [id, :facts, key]) do
      nil -> []
      refs when is_list(refs) -> refs
      ref -> [ref]
    end
  end

  defp reaches?([], _, _, _, _), do: false
  defp reaches?([origin | _], origin, _, _, _), do: true

  defp reaches?([id | rest], origin, key, tickets, seen) do
    if MapSet.member?(seen, id) do
      reaches?(rest, origin, key, tickets, seen)
    else
      reaches?(references(tickets, id, key) ++ rest, origin, key, tickets, MapSet.put(seen, id))
    end
  end

  defp ancestor?(_, nil, _, _), do: false
  defp ancestor?(id, id, _, _), do: true

  defp ancestor?(id, parent, tickets, seen),
    do:
      not MapSet.member?(seen, parent) and
        ancestor?(
          id,
          get_in(tickets, [parent, :facts, "parent"]),
          tickets,
          MapSet.put(seen, parent)
        )

  defp files(root) do
    directory = Path.join(root, "tickets")

    case File.ls(directory) do
      {:ok, names} ->
        names
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort()
        |> Enum.map(&Path.join(directory, &1))

      {:error, :enoent} ->
        []

      {:error, reason} ->
        raise File.Error, reason: reason, action: "list tickets", path: directory
    end
  end

  defp path(root, id), do: Path.join([root, "tickets", id <> ".md"])
  defp parse_reason({:error, reason}) when is_binary(reason), do: reason
  defp parse_reason(other), do: "cannot read regular ticket file: #{inspect(other)}"
end
