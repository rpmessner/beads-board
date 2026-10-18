defmodule Foreman.Test.AmbiguousForge do
  @behaviour Foreman.Forge
  defdelegate capabilities(), to: Foreman.Forge.Fake
  defdelegate list(remote, opts), to: Foreman.Forge.Fake

  def merge(remote, number, sha, opts) do
    send(Keyword.fetch!(opts, :observer), :merge)
    {:ok, _} = Foreman.Forge.Fake.merge(remote, number, sha, opts)
    {:error, :outcome_unknown}
  end

  defdelegate retarget(remote, number, base, opts), to: Foreman.Forge.Fake
end
