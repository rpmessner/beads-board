defmodule Board.Repo.Migrations.CreateMergeActions do
  use Ecto.Migration

  def change do
    create table(:merge_actions) do
      add :repo_key, :text, null: false
      add :remote, :text, null: false
      add :number, :integer, null: false
      add :head_sha, :text, null: false
      add :requested_by, :text, null: false
      add :facts, :map, null: false
      add :state, :text, null: false
      add :error, :text
      add :merge_sha, :text
      add :claimed_at, :utc_datetime_usec
      add :retarget_claimed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:merge_actions, [:remote, :number, :head_sha])
    create index(:merge_actions, [:repo_key, :inserted_at])
  end
end
