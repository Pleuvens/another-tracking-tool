defmodule AnotherTrackingTool.Imports.ImportWorker do
  use Oban.Worker, queue: :imports

  alias AnotherTrackingTool.{Accounts, Catalog, Coerce, Imports, Tracking, WatchStatuses}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "rows" => rows}}) do
    user = Accounts.get_user!(user_id)
    grouped = Enum.group_by(rows, & &1["kind"])
    movie_rows = Map.get(grouped, "movie", [])
    show_rows = Map.get(grouped, "show", [])
    episode_rows = Map.get(grouped, "episode", []) ++ Map.get(grouped, "season", [])

    resolved = fetch_media(user_id, movie_rows, show_rows, episode_rows)

    imported =
      import_movies(user, movie_rows, resolved) +
        import_shows(user, show_rows, resolved) +
        import_episodes(user, episode_rows, resolved)

    Imports.broadcast(
      user_id,
      {:import_done, %{imported: imported, skipped: length(rows) - imported, total: length(rows)}}
    )

    :ok
  end

  defp fetch_media(user_id, movie_rows, show_rows, episode_rows) do
    known = Catalog.enriched_by_tmdb(unique_ids(movie_rows), :movie)

    movie_fetches =
      movie_rows |> unique_by_id() |> Enum.reject(&Map.has_key?(known, &1["tmdb_id"]))

    show_fetches = unique_by_id(show_rows ++ episode_rows)
    total = length(movie_fetches) + length(show_fetches)

    {resolved, done} =
      Enum.reduce(movie_fetches, {known, 0}, fn row, {acc, done} ->
        acc = put_movie(acc, row)
        progress(user_id, done + 1, total)
        {acc, done + 1}
      end)

    {resolved, _} =
      Enum.reduce(show_fetches, {resolved, done}, fn row, {acc, done} ->
        acc = put_show(acc, row)
        progress(user_id, done + 1, total)
        {acc, done + 1}
      end)

    resolved
  end

  defp put_movie(acc, row) do
    case Catalog.fetch_and_enrich(:tmdb, row["tmdb_id"], :movie, %{title_fr: row["title"]}) do
      {:ok, media_item} -> Map.put(acc, row["tmdb_id"], media_item)
      _ -> acc
    end
  end

  defp put_show(acc, row) do
    case Catalog.fetch_tv_with_episodes(row["tmdb_id"], %{title_fr: row["title"]}) do
      {:ok, show} -> Map.put(acc, {:show, row["tmdb_id"]}, show)
      _ -> acc
    end
  end

  defp import_movies(user, movie_rows, resolved) do
    entries = for row <- movie_rows, mi = resolved[row["tmdb_id"]], do: entry(mi, row)
    Tracking.import_entries(user, entries)
  end

  defp import_shows(user, show_rows, resolved) do
    entries =
      for row <- show_rows, show = resolved[{:show, row["tmdb_id"]}], do: entry(show, row)

    Tracking.import_entries(user, entries)
  end

  defp import_episodes(user, episode_rows, resolved) do
    watches =
      episode_rows
      |> Enum.group_by(& &1["tmdb_id"])
      |> Enum.flat_map(fn {tmdb_id, rows} ->
        case resolved[{:show, tmdb_id}] do
          nil -> []
          show -> episode_watches(show, rows)
        end
      end)

    Tracking.import_episode_watches(user, watches)
  end

  defp episode_watches(show, rows) do
    index = Catalog.episode_index(show)
    {season_rows, episode_rows} = Enum.split_with(rows, &(&1["kind"] == "season"))

    explicit =
      for row <- episode_rows, episode_id = index[{row["season_number"], row["episode_number"]}] do
        watch(show, episode_id, row["watched_on"])
      end

    filled =
      for row <- season_rows,
          number <- 1..row["progress"]//1,
          episode_id = index[{row["season_number"], number}] do
        watch(show, episode_id, row["watched_on"])
      end

    explicit ++ filled
  end

  defp watch(show, episode_id, watched_on) do
    %{episode_id: episode_id, media_item_id: show.id, watched_on: Coerce.date(watched_on)}
  end

  defp entry(media_item, row) do
    %{
      media_item_id: media_item.id,
      status: WatchStatuses.from_string(row["status"]),
      rating: row["rating"],
      watched_on: Coerce.date(row["watched_on"])
    }
  end

  defp unique_ids(rows), do: rows |> Enum.map(& &1["tmdb_id"]) |> Enum.uniq()
  defp unique_by_id(rows), do: Enum.uniq_by(rows, & &1["tmdb_id"])

  defp progress(user_id, done, total),
    do: Imports.broadcast(user_id, {:import_progress, %{done: done, total: total}})
end
