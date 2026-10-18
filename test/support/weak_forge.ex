defmodule Board.Test.WeakForge do
  @behaviour Board.Forge
  def capabilities, do: %{write: true, head_guard: false, retarget: false}

  def list(remote, opts) do
    send(Keyword.fetch!(opts, :observer), :read)
    Board.Forge.Fake.list(remote, opts)
  end

  def merge(remote, number, sha, opts) do
    send(Keyword.fetch!(opts, :observer), :merge)
    Board.Forge.Fake.merge(remote, number, sha, opts)
  end

  def retarget(_, _, _, _), do: raise("retarget must not be called")
end
