defmodule AnotherTrackingTool.Repo.Migrations.CreateEpisodeWatches do
  use Ecto.Migration

  def change do
    create table(:episode_watches) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :episode_id, references(:episodes, on_delete: :delete_all), null: false
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :watched_on, :date

      timestamps()
    end

    create unique_index(:episode_watches, [:user_id, :episode_id])
    create index(:episode_watches, [:user_id, :media_item_id])
  end
end
