defmodule AnotherTrackingTool.Catalog.Series do
  @moduledoc "Persistence for episodic media: seasons and their episodes."

  alias AnotherTrackingTool.Catalog.{Episode, MediaItem, Season}
  alias AnotherTrackingTool.Repo

  def upsert_season(%MediaItem{id: media_item_id}, attrs) do
    attrs
    |> Map.put(:media_item_id, media_item_id)
    |> then(&Season.changeset(%Season{}, &1))
    |> Repo.insert(
      on_conflict:
        {:replace, ~w(tmdb_id name overview air_date poster_path episode_count updated_at)a},
      conflict_target: [:media_item_id, :season_number],
      returning: true
    )
  end

  def upsert_episode(%Season{} = season, attrs) do
    attrs
    |> Map.merge(%{media_item_id: season.media_item_id, season_id: season.id})
    |> then(&Episode.changeset(%Episode{}, &1))
    |> Repo.insert(
      on_conflict: {:replace, ~w(tmdb_id name overview air_date still_path runtime updated_at)a},
      conflict_target: [:media_item_id, :season_number, :episode_number],
      returning: true
    )
  end

  def get_season(%MediaItem{id: media_item_id}, season_number),
    do: Repo.get_by(Season, media_item_id: media_item_id, season_number: season_number)
end
