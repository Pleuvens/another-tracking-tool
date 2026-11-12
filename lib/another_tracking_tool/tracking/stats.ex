defmodule AnotherTrackingTool.Tracking.Stats do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, Period, WatchEntry}

  def watch_totals(%User{id: user_id}, period) do
    since = Period.start(period)
    films = film_totals(user_id, since)
    episodes = episode_totals(user_id, since)

    films
    |> Map.merge(episodes)
    |> Map.put(:minutes, films.film_minutes + episodes.episode_minutes)
  end

  defp film_totals(user_id, since) do
    from(e in WatchEntry,
      join: m in assoc(e, :media_item),
      where: e.user_id == ^user_id and e.status == :completed and m.kind == :movie,
      select: %{films: count(e.id), film_minutes: coalesce(sum(m.runtime), 0)}
    )
    |> Period.since(since)
    |> Repo.one()
  end

  defp episode_totals(user_id, since) do
    from(w in EpisodeWatch,
      join: ep in assoc(w, :episode),
      where: w.user_id == ^user_id,
      select: %{
        episodes: count(w.id),
        episode_minutes: coalesce(sum(ep.runtime), 0),
        series: count(w.media_item_id, :distinct)
      }
    )
    |> Period.since(since)
    |> Repo.one()
  end
end
