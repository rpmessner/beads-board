defmodule Foreman.Test.WeakForge do
  @behaviour Foreman.Forge
  def capabilities,
    do: %{write: true, head_guard: false, retarget: false, create_change_request: false}

  defdelegate branch_sha(remote, branch, opts), to: Foreman.Forge.Fake
  def create_change_request(_, _, _), do: {:error, :unsupported}

  def list(remote, opts) do
    send(Keyword.fetch!(opts, :observer), :read)
    Foreman.Forge.Fake.list(remote, opts)
  end

  def merge(remote, number, sha, opts) do
    send(Keyword.fetch!(opts, :observer), :merge)
    Foreman.Forge.Fake.merge(remote, number, sha, opts)
  end

  def retarget(_, _, _, _), do: raise("retarget must not be called")
end
