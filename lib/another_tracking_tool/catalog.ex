defmodule AnotherTrackingTool.Catalog do
  @moduledoc "The local media catalog: read-through search and provider-neutral persistence."

  import Ecto.Query

  alias AnotherTrackingTool.Catalog.{Episode, MediaItem, Season}
  alias AnotherTrackingTool.Catalog.EnrichMediaItemWorker
  alias AnotherTrackingTool.Providers
  alias AnotherTrackingTool.Repo

  @cinema_kinds AnotherTrackingTool.MediaEnums.cinema_kinds()

  @id_columns %{
    tmdb: :tmdb_id,
    imdb: :imdb_id,
    tvdb: :tvdb_id,
    mal: :mal_id,
    anilist: :anilist_id
  }

  @shell_replace ~w(original_title title_fr overview_fr poster_path backdrop_path released_on
    original_language tmdb_popularity tmdb_vote_average tmdb_vote_count updated_at)a

  def provider_for(kind) when kind in @cinema_kinds, do: Providers.Tmdb

  def subscribe(%MediaItem{id: id}),
    do: Phoenix.PubSub.subscribe(AnotherTrackingTool.PubSub, "catalog:#{id}")

  def broadcast_updated(media_item_id),
    do:
      Phoenix.PubSub.broadcast(
        AnotherTrackingTool.PubSub,
        "catalog:#{media_item_id}",
        {:catalog_updated, media_item_id}
      )

  def search(query, opts \\ []) do
    result =
      Enum.reduce_while(search_providers(), {:ok, []}, fn provider, {:ok, acc} ->
        with {:ok, results} <- provider.search(query, opts),
             {:ok, items} <- upsert_all(results) do
          {:cont, {:ok, acc ++ items}}
        else
          error -> {:halt, error}
        end
      end)

    with {:ok, items} <- result do
      Enum.each(items, &ensure_details/1)
      {:ok, items}
    end
  end

  def upsert_media_item(%{source: source, source_id: source_id} = attrs) do
    attrs
    |> Map.drop([:source, :source_id])
    |> Map.put(@id_columns[source], source_id)
    |> then(&MediaItem.changeset(%MediaItem{}, &1))
    |> Repo.insert(
      on_conflict: {:replace, @shell_replace},
      conflict_target: conflict_target(source),
      returning: true
    )
  end

  def update_media_item(%MediaItem{} = media_item, attrs),
    do: media_item |> MediaItem.changeset(attrs) |> Repo.update()

  def fetch_media_item(id) do
    case Repo.get(MediaItem, id) do
      nil -> {:error, :not_found}
      media_item -> {:ok, media_item}
    end
  end

  def get_by_external(source, source_id, opts \\ []) do
    Repo.get_by(MediaItem, [{@id_columns[source], source_id}] ++ Keyword.take(opts, [:kind]))
  end

  def fetch_tv_with_episodes(tmdb_id, fallback_attrs \\ %{}) do
    with {:ok, show} <- fetch_and_enrich(:tmdb, tmdb_id, :tv, fallback_attrs) do
      provider = provider_for(:tv)

      for season_number <- season_numbers(show.id) do
        if episode_count(show.id, season_number) == 0,
          do: provider.sync_season(show, season_number)
      end

      {:ok, show}
    end
  end

  def episode_index(%MediaItem{id: id}) do
    from(e in Episode,
      where: e.media_item_id == ^id,
      select: {e.season_number, e.episode_number, e.id}
    )
    |> Repo.all()
    |> Map.new(fn {s, e, id} -> {{s, e}, id} end)
  end

  defp season_numbers(media_item_id) do
    Repo.all(
      from s in Season,
        where: s.media_item_id == ^media_item_id and s.season_number >= 1,
        select: s.season_number
    )
  end

  defp episode_count(media_item_id, season_number) do
    Repo.one(
      from e in Episode,
        where: e.media_item_id == ^media_item_id and e.season_number == ^season_number,
        select: count(e.id)
    )
  end

  def seasons_with_episodes(%MediaItem{id: id}) do
    episodes = from(e in Episode, order_by: e.episode_number)

    from(s in Season,
      where: s.media_item_id == ^id and s.season_number >= 1,
      order_by: s.season_number,
      preload: [episodes: ^episodes]
    )
    |> Repo.all()
  end

  def enriched_by_tmdb(tmdb_ids, kind) do
    from(m in MediaItem,
      where: m.kind == ^kind and m.tmdb_id in ^tmdb_ids and not is_nil(m.details_synced_at)
    )
    |> Repo.all()
    |> Map.new(&{&1.tmdb_id, &1})
  end

  def ensure_details(%MediaItem{details_synced_at: nil} = media_item) do
    with {:ok, _job} <-
           %{media_item_id: media_item.id} |> EnrichMediaItemWorker.new() |> Oban.insert() do
      {:ok, media_item}
    end
  end

  def ensure_details(%MediaItem{} = media_item), do: {:ok, media_item}

  def fetch_and_enrich(source, source_id, kind, fallback_attrs \\ %{}) do
    case get_by_external(source, source_id, kind: kind) do
      %MediaItem{details_synced_at: synced} = media_item when not is_nil(synced) ->
        {:ok, media_item}

      _ ->
        upsert_and_enrich(source, source_id, kind, fallback_attrs)
    end
  end

  defp upsert_and_enrich(source, source_id, kind, fallback_attrs) do
    attrs = Map.merge(fallback_attrs, %{source: source, source_id: source_id, kind: kind})

    with {:ok, media_item} <- upsert_media_item(attrs) do
      provider_for(kind).enrich(media_item)
    end
  end

  defp search_providers, do: [Providers.Tmdb]

  defp upsert_all(attrs_list) do
    attrs_list
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, acc} ->
      case upsert_media_item(attrs) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp conflict_target(:tmdb),
    do: {:unsafe_fragment, "(kind, tmdb_id) WHERE tmdb_id IS NOT NULL"}
end
