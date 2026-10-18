defmodule Foreman.Beads.Store do
  @moduledoc "Physical store admission facts. Called only by external-read jobs. No store mutation."
  alias Foreman.Beads.Command

  def resolve(path) do
    with {:ok, physical} <- Command.run("/", ["/usr/bin/realpath", "-e", path]),
         physical = String.trim(physical),
         false <- File.exists?(Path.join(physical, ".beads/redirect")),
         {:ok, %File.Stat{type: :directory} = stat} <- File.lstat(Path.join(physical, ".beads")),
         {:ok, metadata} <- File.read(Path.join(physical, ".beads/metadata.json")),
         {:ok, metadata} <- Jason.decode(metadata),
         "embedded" <- Map.get(metadata, "dolt_mode", "embedded"),
         :ok <- embedded_config(physical) do
      {:ok, physical, "#{stat.major_device}:#{stat.inode}"}
    else
      "server" -> {:error, :server_mode}
      {:error, :server_mode} -> {:error, :server_mode}
      _ -> {:error, :unreachable}
    end
  end

  defp embedded_config(path) do
    case File.read(Path.join(path, ".beads/config.yaml")) do
      {:ok, text} ->
        # bd permits config.yaml to override metadata's mode. Never open a server
        # because a metadata-only check incorrectly classified it as embedded.
        case Regex.run(~r/^\s*["']?dolt\.mode["']?\s*:\s*([^#\n]+)/m, text) do
          nil ->
            :ok

          [_, mode] ->
            mode = mode |> String.trim() |> String.trim("\"") |> String.trim("'")
            if mode == "embedded", do: :ok, else: {:error, :server_mode}
        end

      {:error, :enoent} ->
        :ok

      _ ->
        {:error, :unreachable}
    end
  end
end
