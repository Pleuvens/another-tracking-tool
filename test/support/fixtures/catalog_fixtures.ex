defmodule AnotherTrackingTool.CatalogFixtures do
  @moduledoc "Persisted catalog records for tests."

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.Series

  def media_item_fixture(attrs \\ %{}) do
    {:ok, media_item} =
      attrs
      |> Enum.into(%{
        source: :tmdb,
        source_id: System.unique_integer([:positive]),
        kind: :movie,
        title_fr: "Un film"
      })
      |> Catalog.upsert_media_item()

    media_item
  end

  def season_fixture(media_item, attrs \\ %{}) do
    {:ok, season} =
      Series.upsert_season(media_item, Enum.into(attrs, %{season_number: 1, name: "Saison 1"}))

    season
  end

  def episode_fixture(_media_item, season, attrs \\ %{}) do
    {:ok, episode} =
      Series.upsert_episode(
        season,
        Enum.into(attrs, %{
          season_number: season.season_number,
          episode_number: System.unique_integer([:positive]),
          name: "Un épisode",
          air_date: ~D[2020-01-01]
        })
      )

    episode
  end
end
