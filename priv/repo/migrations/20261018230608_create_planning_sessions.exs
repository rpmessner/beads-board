defmodule Foreman.Repo.Migrations.CreatePlanningSessions do
  use Ecto.Migration

  def change do
    create table(:planning_sessions, primary_key: false) do
      add :session_id, :uuid, primary_key: true
      add :project, :text, null: false
      add :ticket, :text, null: false
      add :window, :text
      add :workdir, :text, null: false
      add :state, :text, null: false
      add :error, :text
      add :launched_at, :utc_datetime_usec, null: false
      add :observed_at, :utc_datetime_usec
    end

    create unique_index(:planning_sessions, [:project, :ticket])
  end
end
