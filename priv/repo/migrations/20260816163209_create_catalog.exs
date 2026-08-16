defmodule AnotherTrackingTool.Repo.Migrations.CreateCatalog do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :kind, :string, null: false
      add :tmdb_id, :integer
      add :imdb_id, :string
      add :tvdb_id, :integer
      add :mal_id, :integer
      add :anilist_id, :integer
      add :original_title, :string
      add :title_fr, :string
      add :title_en, :string
      add :overview_fr, :text
      add :overview_en, :text
      add :poster_path, :string
      add :backdrop_path, :string
      add :released_on, :date
      add :original_language, :string
      add :tmdb_popularity, :float
      add :tmdb_vote_average, :float
      add :tmdb_vote_count, :integer
      add :details_synced_at, :utc_datetime

      timestamps()
    end

    create unique_index(:media_items, [:kind, :tmdb_id], where: "tmdb_id IS NOT NULL")
    create unique_index(:media_items, [:imdb_id], where: "imdb_id IS NOT NULL")
    create unique_index(:media_items, [:mal_id], where: "mal_id IS NOT NULL")

    create table(:tmdb_genres) do
      add :tmdb_id, :integer, null: false
      add :name_fr, :string
      add :name_en, :string

      timestamps()
    end

    create unique_index(:tmdb_genres, [:tmdb_id])

    create table(:media_item_tmdb_genres, primary_key: false) do
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :tmdb_genre_id, references(:tmdb_genres, on_delete: :delete_all), null: false
    end

    create unique_index(:media_item_tmdb_genres, [:media_item_id, :tmdb_genre_id])
    create index(:media_item_tmdb_genres, [:tmdb_genre_id])

    create table(:seasons) do
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :tmdb_id, :integer
      add :season_number, :integer, null: false
      add :name, :string
      add :overview, :text
      add :air_date, :date
      add :poster_path, :string
      add :episode_count, :integer

      timestamps()
    end

    create unique_index(:seasons, [:media_item_id, :season_number])

    create table(:episodes) do
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false
      add :season_id, references(:seasons, on_delete: :delete_all), null: false
      add :tmdb_id, :integer
      add :season_number, :integer, null: false
      add :episode_number, :integer, null: false
      add :name, :string
      add :overview, :text
      add :air_date, :date
      add :still_path, :string
      add :runtime, :integer

      timestamps()
    end

    create unique_index(:episodes, [:media_item_id, :season_number, :episode_number])
  end
end
