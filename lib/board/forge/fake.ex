defmodule Board.Forge.Fake do
  @behaviour Board.Forge
  use Agent
  def start_link(snapshot), do: Agent.start_link(fn -> snapshot end)
  def list(_, opts), do: Agent.get(Keyword.fetch!(opts, :server), &{:ok, &1})
  def capabilities, do: %{head_guard: true, retarget: true, write: false}
  def merge(_, _, _, _), do: {:error, :read_only}
  def retarget(_, _, _, _), do: {:error, :read_only}
end
