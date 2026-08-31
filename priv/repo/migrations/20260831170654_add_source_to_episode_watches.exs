defmodule AnotherTrackingTool.Repo.Migrations.AddSourceToEpisodeWatches do
  use Ecto.Migration

  def change do
    alter table(:episode_watches) do
      add :source, :string, null: false, default: "manual"
    end
  end
end
