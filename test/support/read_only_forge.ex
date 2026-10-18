defmodule Foreman.Test.ReadOnlyForge do
  @behaviour Foreman.Forge
  def capabilities,
    do: %{write: false, head_guard: true, retarget: true, create_change_request: false}

  def branch_sha(_, _, _), do: raise("read-only job must stop before IO")
  def create_change_request(_, _, _), do: raise("read-only job must not create")
  def list(_, _), do: raise("read-only job must stop before IO")
  def merge(_, _, _, _), do: raise("read-only job must not merge")
  def retarget(_, _, _, _), do: raise("read-only job must not retarget")
end
