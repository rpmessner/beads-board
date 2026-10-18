defmodule Board.Repo.Migrations.AddAgentSpool do
  use Ecto.Migration

  def change do
    create table(:spooled_events) do
      add :request_id, :uuid, null: false
      add :request, :map, null: false
      add :state, :text, null: false, default: "pending"
      add :result, :map
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("clock_timestamp()")
    end

    create unique_index(:spooled_events, [:request_id])
    create index(:spooled_events, [:state, :id])

    create table(:agent_receipts, primary_key: false) do
      add :request_id, :uuid, primary_key: true
      add :request, :map, null: false
      add :status, :integer, null: false
      add :body, :map, null: false
    end
  end
end
