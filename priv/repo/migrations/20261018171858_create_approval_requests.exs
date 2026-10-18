defmodule Board.Repo.Migrations.CreateApprovalRequests do
  use Ecto.Migration

  def change do
    create table(:approval_requests, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :kind, :text, null: false
      add :actor, :text, null: false
      add :session, :text
      add :facts, :map, null: false
      add :state, :text, null: false
      add :outcome, :map, null: false, default: %{}
      add :note, :text
      timestamps(type: :utc_datetime_usec)
    end

    create index(:approval_requests, [:state, :inserted_at])
    create index(:approval_requests, [:repo_key, :bead_id])

    create table(:request_events) do
      add :request_id, references(:approval_requests, type: :uuid), null: false
      add :event, :text, null: false
      add :from_state, :text, null: false
      add :to_state, :text, null: false
      add :payload, :map, null: false
      add :effects, :map, null: false
      add :inserted_at, :utc_datetime_usec, null: false
    end
  end
end
