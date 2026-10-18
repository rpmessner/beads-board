defmodule Board.Repo.Migrations.AddStageOverlay do
  use Ecto.Migration

  def change do
    create table(:epics) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :beads_epic_id, :text
      add :title, :text
      add :spec_link, :text
      add :stage, :text, null: false
      add :stage_changed_at, :utc_datetime_usec, null: false
      add :lock_version, :integer, null: false, default: 1
      add :orphaned_at, :utc_datetime_usec
    end

    create unique_index(:epics, [:repo_key, :bead_id])
    create unique_index(:epics, [:repo_key, :beads_epic_id])

    create table(:stage_events) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :machine, :text, null: false
      add :event, :text, null: false
      add :payload, :map, null: false, default: %{}
      add :source, :text, null: false
      add :actor, :text, null: false
      add :from_stage, :text
      add :to_stage, :text, null: false
      add :outcome, :text, null: false
      add :effects, {:array, :map}, null: false, default: []
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:stage_events, [:repo_key, :bead_id, :id])

    create table(:overlay_effects) do
      add :event_id, references(:stage_events, on_delete: :restrict), null: false
      add :kind, :text, null: false
      add :name, :text, null: false
      add :payload, :map, null: false
    end

    create table(:sessions) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :window, :text, null: false
      add :details, :map, null: false, default: %{}
      add :started_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :ended_at, :utc_datetime_usec
    end

    create index(:sessions, [:repo_key, :bead_id, :id])

    create table(:agent_notes) do
      add :event_id, references(:stage_events, on_delete: :restrict), null: false
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :actor, :text, null: false
      add :kind, :text, null: false
      add :body, :text
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create table(:overlay_cr_links) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :number, :bigint, null: false
    end

    create unique_index(:overlay_cr_links, [:repo_key, :bead_id, :number])

    create table(:epic_links) do
      add :repo_key, :text, null: false
      add :bead_id, :text, null: false
      add :epic_repo_key, :text, null: false
      add :epic_bead_id, :text, null: false
    end

    create unique_index(:epic_links, [:repo_key, :bead_id, :epic_repo_key, :epic_bead_id])
  end
end
