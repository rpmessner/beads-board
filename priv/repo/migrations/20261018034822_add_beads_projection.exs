defmodule Board.Repo.Migrations.AddBeadsProjection do
  use Ecto.Migration

  def change do
    create table(:bead_repos, primary_key: false) do
      add :key, :text, primary_key: true
      add :export_sha256, :text, null: false
      add :synced_at, :utc_datetime_usec, null: false
    end

    create table(:beads, primary_key: false) do
      add :repo_key, references(:bead_repos, column: :key, type: :text, on_delete: :delete_all),
        primary_key: true

      add :bead_id, :text, primary_key: true
      add :raw, :map, null: false
    end

    # No projection foreign key: process facts must survive a projection rebuild.
    create table(:tickets) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :stage, :text, null: false
      add :stage_changed_at, :utc_datetime_usec, null: false
      add :lock_version, :integer, null: false, default: 1
      add :orphaned_at, :utc_datetime_usec
    end

    create unique_index(:tickets, [:repo_key, :bead_id])
  end
end
