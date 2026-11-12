defmodule AnotherTrackingTool.Repo.Migrations.AddRuntimeToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :runtime, :integer
    end
  end
end
