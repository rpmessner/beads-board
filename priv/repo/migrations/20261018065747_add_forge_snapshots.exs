defmodule Board.Repo.Migrations.AddForgeSnapshots do
  use Ecto.Migration

  def change do
    create table(:forge_snapshots, primary_key: false) do
      add :repo_key, :text, primary_key: true
      add :remote, :text, null: false
      add :snapshot, :map, null: false, default: %{}
      add :state, :text, null: false, default: "idle"
      add :error, :text
      add :synced_at, :utc_datetime_usec
      add :attempted_at, :utc_datetime_usec
    end
  end
end
