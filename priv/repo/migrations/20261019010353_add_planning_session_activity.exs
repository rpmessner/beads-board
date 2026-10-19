defmodule Foreman.Repo.Migrations.AddPlanningSessionActivity do
  use Ecto.Migration

  def change do
    alter table(:planning_sessions) do
      add :last_activity_at, :utc_datetime_usec
    end

    execute("UPDATE planning_sessions SET last_activity_at = CURRENT_TIMESTAMP", "SELECT 1")
  end
end
