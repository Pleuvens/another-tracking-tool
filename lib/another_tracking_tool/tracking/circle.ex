defmodule AnotherTrackingTool.Tracking.Circle do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, Period, WatchEntry}

  def circle_latest(%User{id: user_id}, limit \\ 8) do
    (latest_film_per_user(user_id) ++ latest_episode_per_user(user_id))
    |> Enum.group_by(& &1.user.id)
    |> Enum.map(fn {_user_id, watches} -> Enum.max_by(watches, & &1.at, DateTime) end)
    |> Enum.sort_by(& &1.at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp latest_film_per_user(user_id) do
    from(e in WatchEntry,
      join: m in assoc(e, :media_item),
      where: e.user_id != ^user_id and e.status == :completed and m.kind == :movie,
      distinct: e.user_id,
      order_by: [
        asc: e.user_id,
        desc: coalesce(fragment("(?)::timestamp", e.watched_on), e.updated_at)
      ],
      preload: [:user, :media_item]
    )
    |> Repo.all()
    |> Enum.map(fn entry ->
      %{
        user: entry.user,
        media_item: entry.media_item,
        episode: nil,
        rating: entry.rating,
        at: Period.at(entry.watched_on, entry.updated_at)
      }
    end)
  end

  defp latest_episode_per_user(user_id) do
    from(w in EpisodeWatch,
      where: w.user_id != ^user_id,
      distinct: w.user_id,
      order_by: [
        asc: w.user_id,
        desc: coalesce(fragment("(?)::timestamp", w.watched_on), w.inserted_at)
      ],
      preload: [:user, :media_item, :episode]
    )
    |> Repo.all()
    |> Enum.map(fn watch ->
      %{
        user: watch.user,
        media_item: watch.media_item,
        episode: watch.episode,
        rating: nil,
        at: Period.at(watch.watched_on, watch.inserted_at)
      }
    end)
  end
end
