defmodule Board.Repo.Migrations.AddRuntimeSnapshots do
  use Ecto.Migration

  def change do
    create table(:board_config, primary_key: false) do
      add :id, :integer, primary_key: true
      add :config, :map, null: false
      add :error, :text
      add :source, :text, null: false
      add :discovered, {:array, :text}, null: false, default: []
      add :loaded_at, :utc_datetime_usec, null: false
    end

    create table(:repo_sync, primary_key: false) do
      add :key, :text, primary_key: true
      add :state, :text, null: false
      add :reason, :text
      add :checked_at, :utc_datetime_usec, null: false
      add :succeeded_at, :utc_datetime_usec
    end
  end
end
