defmodule Board.Requests.Request do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder,
           only: [
             :id,
             :repo_key,
             :bead_id,
             :kind,
             :actor,
             :session,
             :facts,
             :state,
             :outcome,
             :note,
             :inserted_at,
             :updated_at
           ]}
  schema "approval_requests" do
    field :repo_key, :string
    field :bead_id, :string
    field :kind, :string
    field :actor, :string
    field :session, :string
    field :facts, :map
    field :state, :string
    field :outcome, :map, default: %{}
    field :note, :string
    timestamps(type: :utc_datetime_usec)
  end
end
