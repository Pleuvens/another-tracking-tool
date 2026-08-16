defmodule AnotherTrackingTool.Catalog do
  @moduledoc "The local media catalog: read-through search and provider-neutral persistence."

  alias AnotherTrackingTool.Catalog.MediaItem
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

  def search(query, opts \\ []) do
    Enum.reduce_while(search_providers(), {:ok, []}, fn provider, {:ok, acc} ->
      with {:ok, results} <- provider.search(query, opts),
           {:ok, items} <- upsert_all(results) do
        {:cont, {:ok, acc ++ items}}
      else
        error -> {:halt, error}
      end
    end)
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

  def ensure_details(%MediaItem{details_synced_at: nil} = media_item) do
    with {:ok, _job} <-
           %{media_item_id: media_item.id} |> EnrichMediaItemWorker.new() |> Oban.insert() do
      {:ok, media_item}
    end
  end

  def ensure_details(%MediaItem{} = media_item), do: {:ok, media_item}

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
