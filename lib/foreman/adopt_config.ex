defmodule Foreman.AdoptConfig do
  @moduledoc "Append-only registration for the explicit adopt command."

  def append(directory, entry) do
    File.mkdir_p!(directory)
    lock = Path.join(directory, ".foreman-adopt-lock")

    case File.mkdir(lock) do
      :ok ->
        try do
          with {:ok, text} <- plan(directory, entry) do
            if text != "", do: File.write!(Path.join(directory, "foreman.toml"), text, [:append])
            {:ok, text}
          end
        after
          File.rmdir!(lock)
        end

      {:error, reason} ->
        {:error, "config lock: #{inspect(reason)}"}
    end
  end

  def plan(directory, entry) do
    path = Path.join(directory, "foreman.toml")

    with :ok <- regular_or_absent(path),
         {:ok, config} <- Foreman.Config.load(directory) do
      repos = config["repos"]
      matches = Enum.filter(repos, &(&1["key"] == entry["key"] or &1["path"] == entry["path"]))

      case matches do
        [] ->
          text =
            "\n[[repos]]\n" <>
              Enum.map_join(~w(key path prefix github tickets), "", fn key ->
                if entry[key], do: "#{key} = #{Jason.encode!(entry[key])}\n", else: ""
              end)

          # Validate the exact appended document, not just the entry in isolation.
          old = if File.exists?(path), do: File.read!(path), else: ""

          with {:ok, parsed} <- TomlElixir.decode(old <> text, spec: :"1.0.0"),
               :ok <- Foreman.Config.Schema.validate(parsed) do
            {:ok, text}
          end

        [repo] ->
          if Enum.all?(entry, fn {key, value} -> repo[key] == value end),
            do: {:ok, ""},
            else:
              {:error,
               "duplicate repo key or path; explicitly update the existing entry to tickets = files before adoption"}

        _ ->
          {:error, "duplicate repo key or path"}
      end
    end
  end

  defp regular_or_absent(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> :ok
      {:error, :enoent} -> :ok
      _ -> {:error, "config must be a regular file"}
    end
  end
end
