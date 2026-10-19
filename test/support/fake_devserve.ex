defmodule Foreman.FakeDevserve do
  @moduledoc false
  def list, do: {:ok, Process.get(:devserve_previews, [])}

  def up(path, owner) do
    if callback = Process.get(:devserve_up), do: callback.()

    row = %{
      "unit" => "devserve-test.service",
      "worktree" => path,
      "owner" => owner,
      "state" => "running",
      "missing" => false,
      "url" => "http://127.0.0.1:4888"
    }

    Process.put(:devserve_previews, [row])
    :ok
  end

  def down(unit) do
    if Process.get(:devserve_drop_failure) do
      {:error, "database ownership mismatch"}
    else
      Process.put(
        :devserve_previews,
        Enum.reject(Process.get(:devserve_previews, []), &(&1["unit"] == unit))
      )

      :ok
    end
  end

  def logs(_), do: {:ok, "Listening on localhost\n"}
end
