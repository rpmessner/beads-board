defmodule Foreman.Repo.Migrations.RetainEndedPlanningWindows do
  use Ecto.Migration

  def change do
    alter table(:planning_sessions) do
      add :previous_windows, {:array, :map}, default: [], null: false
    end
  end
end
