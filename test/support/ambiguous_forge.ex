defmodule Board.Test.AmbiguousForge do
  @behaviour Board.Forge
  defdelegate capabilities(), to: Board.Forge.Fake
  defdelegate list(remote, opts), to: Board.Forge.Fake

  def merge(remote, number, sha, opts) do
    send(Keyword.fetch!(opts, :observer), :merge)
    {:ok, _} = Board.Forge.Fake.merge(remote, number, sha, opts)
    {:error, :outcome_unknown}
  end

  defdelegate retarget(remote, number, base, opts), to: Board.Forge.Fake
end
