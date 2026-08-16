defmodule AnotherTrackingTool.Providers.Tmdb do
  @moduledoc "TMDB metadata provider — implements the catalog provider behaviour."

  @behaviour AnotherTrackingTool.Catalog.Provider

  require Logger

  import Ecto.Query

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.{MediaItem, Season, Series, TmdbGenre}
  alias AnotherTrackingTool.Providers.Tmdb.SyncSeasonWorker
  alias AnotherTrackingTool.{Coerce, MediaEnums, Repo, Tmdb}

  @impl true
  def source, do: :tmdb

  @impl true
  def search(query, opts \\ []) do
    with {:ok, %{"results" => results}} <- Tmdb.search_multi(query, opts) do
      items =
        Enum.flat_map(results, fn m ->
          case MediaEnums.to_existing_cinema_kind(m["media_type"]) do
            nil -> []
            kind -> [media_item_attrs(kind, m)]
          end
        end)

      {:ok, items}
    end
  end

  @impl true
  def enrich(%MediaItem{kind: kind, tmdb_id: tmdb_id} = media_item) do
    with {:ok, fr} <- Tmdb.details(kind, tmdb_id),
         {:ok, en} <- maybe_fetch_en(kind, tmdb_id, fr),
         {:ok, media_item} <- Catalog.update_media_item(media_item, details_attrs(fr, en)) do
      link_genres(media_item, fr["genres"] || [])
      if kind == :tv, do: sync_seasons(media_item, fr["seasons"] || [])
      Logger.info("tmdb: enriched #{kind} tmdb_id=#{tmdb_id}")
      {:ok, media_item}
    else
      {:error, reason} = error ->
        Logger.warning("tmdb: enrich failed for #{kind} tmdb_id=#{tmdb_id}: #{inspect(reason)}")
        error
    end
  end

  @doc "Sync one season's episodes (called by the per-season fan-out job)."
  def sync_season(%MediaItem{tmdb_id: tmdb_id} = media_item, season_number) do
    with {:ok, %{"episodes" => episodes}} <- Tmdb.season(tmdb_id, season_number),
         %Season{} = season <- Series.get_season(media_item, season_number) do
      Enum.each(episodes, &Series.upsert_episode(season, episode_attrs(&1)))

      Logger.info(
        "tmdb: synced season #{season_number} (#{length(episodes)} eps) media_item=#{media_item.id}"
      )

      :ok
    end
  end

  @doc "Refresh the genre id→name map (FR + EN) for movies and TV."
  def sync_genres do
    with {:ok, movie_fr} <- Tmdb.genres(:movie),
         {:ok, tv_fr} <- Tmdb.genres(:tv),
         {:ok, movie_en} <- Tmdb.genres(:movie, language: "en-US"),
         {:ok, tv_en} <- Tmdb.genres(:tv, language: "en-US") do
      fr = Map.merge(index_genres(movie_fr), index_genres(tv_fr))
      en = Map.merge(index_genres(movie_en), index_genres(tv_en))
      ids = Enum.uniq(Map.keys(fr) ++ Map.keys(en))

      Enum.each(ids, &upsert_genre(%{tmdb_id: &1, name_fr: fr[&1], name_en: en[&1]}))
      Logger.info("tmdb: synced #{length(ids)} genres")
      :ok
    end
  end

  defp maybe_fetch_en(kind, id, fr) do
    if Coerce.presence(fr["overview"]),
      do: {:ok, %{}},
      else: Tmdb.details(kind, id, language: "en-US")
  end

  defp sync_seasons(media_item, seasons) do
    Enum.each(seasons, fn season ->
      Series.upsert_season(media_item, season_attrs(season))

      %{media_item_id: media_item.id, season_number: season["season_number"]}
      |> SyncSeasonWorker.new()
      |> Oban.insert()
    end)
  end

  defp link_genres(media_item, genres) do
    ids = Enum.map(genres, & &1["id"])
    Enum.each(genres, &upsert_genre(%{tmdb_id: &1["id"], name_fr: &1["name"]}))
    rows = Repo.all(from(g in TmdbGenre, where: g.tmdb_id in ^ids))

    media_item
    |> Repo.preload(:tmdb_genres)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tmdb_genres, rows)
    |> Repo.update!()
  end

  defp upsert_genre(attrs) do
    %TmdbGenre{}
    |> TmdbGenre.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, (Map.keys(attrs) -- [:tmdb_id]) ++ [:updated_at]},
      conflict_target: :tmdb_id
    )
  end

  defp media_item_attrs(kind, m) do
    %{
      source: :tmdb,
      source_id: m["id"],
      kind: kind,
      original_title: m["original_title"] || m["original_name"],
      title_fr: m["title"] || m["name"],
      overview_fr: Coerce.presence(m["overview"]),
      poster_path: m["poster_path"],
      backdrop_path: m["backdrop_path"],
      released_on: Coerce.date(m["release_date"] || m["first_air_date"]),
      original_language: m["original_language"],
      tmdb_popularity: m["popularity"],
      tmdb_vote_average: m["vote_average"],
      tmdb_vote_count: m["vote_count"]
    }
  end

  defp details_attrs(fr, en) do
    %{
      original_title: fr["original_title"] || fr["original_name"],
      title_fr: Coerce.presence(fr["title"] || fr["name"]),
      overview_fr: Coerce.presence(fr["overview"]),
      title_en: Coerce.presence(en["title"] || en["name"]),
      overview_en: Coerce.presence(en["overview"]),
      imdb_id: Coerce.presence(get_in(fr, ["external_ids", "imdb_id"])),
      tvdb_id: get_in(fr, ["external_ids", "tvdb_id"]),
      poster_path: fr["poster_path"],
      backdrop_path: fr["backdrop_path"],
      released_on: Coerce.date(fr["release_date"] || fr["first_air_date"]),
      original_language: fr["original_language"],
      tmdb_popularity: fr["popularity"],
      tmdb_vote_average: fr["vote_average"],
      tmdb_vote_count: fr["vote_count"],
      details_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp season_attrs(s) do
    %{
      tmdb_id: s["id"],
      season_number: s["season_number"],
      name: s["name"],
      overview: Coerce.presence(s["overview"]),
      air_date: Coerce.date(s["air_date"]),
      poster_path: s["poster_path"],
      episode_count: s["episode_count"]
    }
  end

  defp episode_attrs(e) do
    %{
      tmdb_id: e["id"],
      season_number: e["season_number"],
      episode_number: e["episode_number"],
      name: e["name"],
      overview: Coerce.presence(e["overview"]),
      air_date: Coerce.date(e["air_date"]),
      still_path: e["still_path"],
      runtime: e["runtime"]
    }
  end

  defp index_genres(%{"genres" => genres}),
    do: Map.new(genres, &{&1["id"], &1["name"]})
end
