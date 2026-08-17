defmodule AnotherTrackingTool.Repo.Migrations.CreateTracking do
  use Ecto.Migration

  def change do
    create table(:watch_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :rating, :integer
      add :watched_on, :date
      add :source, :string, null: false, default: "manual"

      timestamps()
    end

    create unique_index(:watch_entries, [:user_id, :media_item_id])
    create index(:watch_entries, [:media_item_id])

    create table(:comments) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :body, :text, null: false

      timestamps()
    end

    create index(:comments, [:media_item_id, :inserted_at])
  end
end
