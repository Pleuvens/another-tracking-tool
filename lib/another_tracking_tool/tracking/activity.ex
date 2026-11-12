defmodule AnotherTrackingTool.Tracking.Activity do
  import Ecto.Query

  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, WatchEntry}

  def recent_activity(limit \\ 50) do
    (movie_activity(limit) ++ episode_activity(limit))
    |> Enum.sort_by(& &1.at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp movie_activity(limit) do
    from(e in WatchEntry,
      join: m in assoc(e, :media_item),
      where: m.kind == :movie,
      order_by: [desc: e.updated_at],
      limit: ^limit,
      preload: [:user, :media_item]
    )
    |> Repo.all()
    |> Enum.map(fn e ->
      %{
        type: :movie,
        at: activity_at(e.watched_on, e.updated_at),
        user: e.user,
        media_item: e.media_item,
        status: e.status,
        rating: e.rating,
        watched_on: e.watched_on
      }
    end)
  end

  defp episode_activity(limit) do
    from(w in EpisodeWatch,
      order_by: [
        desc: coalesce(w.watched_on, fragment("(?)::date", w.inserted_at)),
        desc: w.inserted_at
      ],
      limit: ^limit,
      preload: [:user, :media_item, :episode]
    )
    |> Repo.all()
    |> Enum.map(fn w ->
      %{
        type: :episode,
        at: activity_at(w.watched_on, w.inserted_at),
        user: w.user,
        media_item: w.media_item,
        episode: w.episode,
        watched_on: w.watched_on
      }
    end)
  end

  defp activity_at(%Date{} = date, _fallback), do: DateTime.new!(date, ~T[00:00:00])
  defp activity_at(nil, fallback), do: fallback
end
