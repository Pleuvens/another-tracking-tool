defmodule AnotherTrackingTool.Tracking.Stats do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Period, Watched}

  def watch_totals(%User{id: user_id}, period) do
    since = Period.start(period)
    films = film_totals(user_id, since)
    episodes = episode_totals(user_id, since)

    films
    |> Map.merge(episodes)
    |> Map.put(:minutes, films.film_minutes + episodes.episode_minutes)
  end

  defp film_totals(user_id, since) do
    user_id
    |> Watched.films()
    |> Period.since(since)
    |> select(
      [entry: e, media_item: m],
      %{films: count(e.id), film_minutes: coalesce(sum(m.runtime), 0)}
    )
    |> Repo.one()
  end

  defp episode_totals(user_id, since) do
    user_id
    |> Watched.episodes()
    |> Period.since(since)
    |> select([watch: w, episode: ep], %{
      episodes: count(w.id),
      episode_minutes: coalesce(sum(ep.runtime), 0),
      series: count(w.media_item_id, :distinct)
    })
    |> Repo.one()
  end
end
