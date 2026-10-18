defmodule Foreman.Test.ReadOnlyForge do
  @behaviour Foreman.Forge
  def capabilities, do: %{write: false, head_guard: true, retarget: true}
  def list(_, _), do: raise("read-only job must stop before IO")
  def merge(_, _, _, _), do: raise("read-only job must not merge")
  def retarget(_, _, _, _), do: raise("read-only job must not retarget")
end
