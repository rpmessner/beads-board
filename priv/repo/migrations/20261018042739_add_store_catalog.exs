defmodule Board.Repo.Migrations.AddStoreCatalog do
  use Ecto.Migration

  def change do
    alter table(:board_config) do
      add :stores, :map, null: false, default: %{}
    end
  end
end
