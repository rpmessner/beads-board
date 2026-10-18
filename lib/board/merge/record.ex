defmodule Board.Merge.Record do
  @moduledoc "Durable intent and outcome of the board's only external write."
  use Ecto.Schema

  schema "merge_actions" do
    field :repo_key, :string
    field :remote, :string
    field :number, :integer
    field :head_sha, :string
    field :requested_by, :string
    field :facts, :map
    field :state, :string
    field :error, :string
    field :merge_sha, :string
    field :claimed_at, :utc_datetime_usec
    field :retarget_claimed_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end
end
