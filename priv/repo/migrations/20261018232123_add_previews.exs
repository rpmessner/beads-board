defmodule Foreman.Repo.Migrations.AddPreviews do
  use Ecto.Migration

  def change do
    create table(:previews) do
      add :worktree, :text, null: false
      add :repo_key, :text
      add :bead_id, :text
      add :state, :text, null: false, default: "none"
      add :launch_requested, :boolean, null: false, default: false
      add :metadata, :map, null: false, default: %{}
      add :error, :text
      add :logs, :text, null: false, default: ""
    end

    create unique_index(:previews, [:worktree])
  end
end
