defmodule AnotherTrackingTool.Tracking.Activity do
  import Ecto.Query

  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, WatchEntry}

  def recent_activity(limit \\ 50) do
    rows = Repo.all(newest_watches(limit))

    movies = load_movies(ids(rows, "movie"))
    episodes = load_episodes(ids(rows, "episode"))
    by_id = Map.merge(movies, episodes)

    Enum.flat_map(rows, fn row -> Map.get(by_id, row.row_id) |> List.wrap() end)
  end

  defp newest_watches(limit) do
    from(r in subquery(union_all(movie_watches(), ^episode_watches())),
      order_by: [desc: r.at],
      limit: ^limit,
      select: %{source: r.source, row_id: r.row_id}
    )
  end

  defp movie_watches do
    from(e in WatchEntry,
      join: m in assoc(e, :media_item),
      where: m.kind == :movie,
      select: %{
        source: type(^"movie", :string),
        row_id: e.id,
        at: coalesce(fragment("(?)::timestamp", e.watched_on), e.updated_at)
      }
    )
  end

  defp episode_watches do
    from(w in EpisodeWatch,
      select: %{
        source: type(^"episode", :string),
        row_id: w.id,
        at: coalesce(fragment("(?)::timestamp", w.watched_on), w.inserted_at)
      }
    )
  end

  defp ids(rows, source),
    do: rows |> Enum.filter(&(&1.source == source)) |> Enum.map(& &1.row_id)

  defp load_movies([]), do: %{}

  defp load_movies(ids) do
    from(e in WatchEntry, where: e.id in ^ids, preload: [:user, :media_item])
    |> Repo.all()
    |> Map.new(fn e ->
      {e.id,
       %{
         type: :movie,
         at: activity_at(e.watched_on, e.updated_at),
         user: e.user,
         media_item: e.media_item,
         status: e.status,
         rating: e.rating,
         watched_on: e.watched_on
       }}
    end)
  end

  defp load_episodes([]), do: %{}

  defp load_episodes(ids) do
    from(w in EpisodeWatch, where: w.id in ^ids, preload: [:user, :media_item, :episode])
    |> Repo.all()
    |> Map.new(fn w ->
      {w.id,
       %{
         type: :episode,
         at: activity_at(w.watched_on, w.inserted_at),
         user: w.user,
         media_item: w.media_item,
         episode: w.episode,
         watched_on: w.watched_on
       }}
    end)
  end

  defp activity_at(%Date{} = date, _fallback), do: DateTime.new!(date, ~T[00:00:00])
  defp activity_at(nil, fallback), do: fallback
end
