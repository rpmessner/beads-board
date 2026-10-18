defmodule Foreman.Beads.JournalLock do
  @moduledoc """
  Passive Linux journal-lock observation. Never opens or acquires a store lock.

  `:clear` means every discovered embedded journal had an existing regular LOCK
  file, with no matching device/inode in the proc snapshot. Missing journals,
  symlinks within the store, unreadable paths, malformed proc data and changed
  identities defer the read. Multiple embedded databases are checked together.

  This is not an atomic admission lock: a writer can start after observation.
  The tested bd version's own open retry handles that race. The caller must still
  provide per-physical-repo single flight and must never signal an agent process.
  Call only from the external-read job, not a LiveView or poller's event handler.
  """
  import Bitwise

  def check(repo, opts \\ []) do
    with {:unix, :linux} <- :os.type(),
         {:ok, before} <- journals(repo),
         {:ok, locks} <- File.read(Keyword.get(opts, :locks_path, "/proc/locks")),
         {:ok, held} <- parse_locks(locks),
         {:ok, after_read} <- journals(repo),
         true <- before == after_read do
      if Enum.any?(before, &MapSet.member?(held, &1)), do: {:defer, :held}, else: :clear
    else
      _ -> {:defer, :indeterminate}
    end
  end

  defp journals(repo) do
    beads = Path.join(repo, ".beads")
    root = Path.join(beads, "embeddeddolt")

    with :ok <- directory(beads),
         :ok <- directory(root),
         {:ok, entries} <- File.ls(root) do
      # The initialization lock may sit alongside database directories. It is
      # not the journal lock. Unknown entries fail closed rather than guessing.
      entries = Enum.reject(entries, &(&1 == ".lock"))

      if entries == [] do
        :error
      else
        Enum.reduce_while(entries, {:ok, []}, fn name, {:ok, acc} ->
          case journal(Path.join(root, name)) do
            {:ok, identity} -> {:cont, {:ok, [identity | acc]}}
            _ -> {:halt, :error}
          end
        end)
        |> case do
          {:ok, identities} -> {:ok, Enum.sort(identities)}
          error -> error
        end
      end
    end
  end

  defp journal(database) do
    dolt = Path.join(database, ".dolt")
    noms = Path.join(dolt, "noms")

    with :ok <- directory(database),
         :ok <- directory(dolt),
         :ok <- directory(noms),
         {:ok, %File.Stat{type: :regular} = stat} <- File.lstat(Path.join(noms, "LOCK")) do
      # On Unix File.Stat.major_device is st_dev, not Linux's decoded major.
      device = stat.major_device
      major = (device >>> 8 &&& 0xFFF) ||| (device >>> 32 &&& 0xFFFFF000)
      minor = (device &&& 0xFF) ||| (device >>> 12 &&& 0xFFFFFF00)
      {:ok, {major, minor, stat.inode}}
    else
      _ -> :error
    end
  end

  defp directory(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> :ok
      _ -> :error
    end
  end

  defp parse_locks(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.reduce_while({:ok, MapSet.new()}, fn line, {:ok, held} ->
      # Blocked waiter rows contain an extra arrow. Matching those is also a
      # reason to defer; there is no need to distinguish owners from waiters.
      fields = line |> String.split() |> Enum.reject(&(&1 == "->"))

      with [number, _kind, _scope, _mode, _pid, token, _start, _end] <- fields,
           true <- Regex.match?(~r/^\d+:$/, number),
           [major, minor, inode] <- String.split(token, ":"),
           {major, ""} <- Integer.parse(major, 16),
           {minor, ""} <- Integer.parse(minor, 16),
           {inode, ""} <- Integer.parse(inode),
           true <- major >= 0 and minor >= 0 and inode >= 0 do
        {:cont, {:ok, MapSet.put(held, {major, minor, inode})}}
      else
        _ -> {:halt, :error}
      end
    end)
  end
end
