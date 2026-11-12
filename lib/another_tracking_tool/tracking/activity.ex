defmodule AnotherTrackingTool.Tracking.Activity do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Episodes, EpisodeWatch, Period, WatchEntry}

  def last_watched(%User{id: user_id}, period, limit \\ 5) do
    since = Period.start(period)

    (film_rows(user_id, since) ++ series_rows(user_id, since))
    |> Enum.sort_by(& &1.at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp film_rows(user_id, since) do
    from(e in WatchEntry,
      join: m in assoc(e, :media_item),
      where: e.user_id == ^user_id and e.status == :completed and m.kind == :movie,
      preload: [media_item: :tmdb_genres]
    )
    |> Period.since(since)
    |> Repo.all()
    |> Enum.map(fn entry ->
      %{
        media_item: entry.media_item,
        at: activity_at(entry.watched_on, entry.updated_at),
        episodes: 0,
        latest_episode: nil,
        progress: nil
      }
    end)
  end

  defp series_rows(user_id, since) do
    counts = episode_counts(user_id, since)
    media_item_ids = Enum.map(counts, & &1.media_item_id)

    shows = shows_by_id(media_item_ids)
    latest = latest_episodes(user_id, since, media_item_ids)
    progress = Episodes.progress_for(user_id, media_item_ids)

    Enum.map(counts, fn count ->
      %{
        media_item: Map.fetch!(shows, count.media_item_id),
        at: count.at,
        episodes: count.episodes,
        latest_episode: Map.get(latest, count.media_item_id),
        progress: Map.get(progress, count.media_item_id)
      }
    end)
  end

  defp episode_counts(user_id, since) do
    from(w in EpisodeWatch,
      where: w.user_id == ^user_id,
      group_by: w.media_item_id,
      select: %{
        media_item_id: w.media_item_id,
        episodes: count(w.id),
        at: max(coalesce(fragment("(?)::timestamp", w.watched_on), w.inserted_at))
      }
    )
    |> Period.since(since)
    |> Repo.all()
    |> Enum.map(&%{&1 | at: as_datetime(&1.at)})
  end

  defp as_datetime(%DateTime{} = at), do: at
  defp as_datetime(%NaiveDateTime{} = at), do: DateTime.from_naive!(at, "Etc/UTC")

  defp latest_episodes(_user_id, _since, []), do: %{}

  defp latest_episodes(user_id, since, media_item_ids) do
    from(w in EpisodeWatch,
      join: e in assoc(w, :episode),
      where: w.user_id == ^user_id and w.media_item_id in ^media_item_ids,
      distinct: w.media_item_id,
      order_by: [asc: w.media_item_id, desc: e.season_number, desc: e.episode_number],
      select: {w.media_item_id, e}
    )
    |> Period.since(since)
    |> Repo.all()
    |> Map.new()
  end

  defp shows_by_id([]), do: %{}

  defp shows_by_id(media_item_ids) do
    from(m in MediaItem, where: m.id in ^media_item_ids)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp activity_at(%Date{} = date, _fallback), do: DateTime.new!(date, ~T[00:00:00])
  defp activity_at(nil, fallback), do: fallback
end
