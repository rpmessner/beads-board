defmodule Foreman.Test.BlockingCreateForge do
  @behaviour Foreman.Forge
  defdelegate capabilities(), to: Foreman.Forge.Fake
  defdelegate list(remote, opts), to: Foreman.Forge.Fake
  defdelegate branch_sha(remote, branch, opts), to: Foreman.Forge.Fake
  defdelegate merge(remote, number, sha, opts), to: Foreman.Forge.Fake
  defdelegate retarget(remote, number, base, opts), to: Foreman.Forge.Fake

  def create_change_request(remote, facts, opts) do
    result = Foreman.Forge.Fake.create_change_request(remote, facts, opts)
    send(Keyword.fetch!(opts, :observer), {:created, self()})

    receive do
      :release -> result
    end
  end
end
