defmodule AnotherTrackingTool.Tracking.Episodes do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.{Episode, MediaItem}
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Broadcast, Entries, EpisodeWatch}

  def watched_episode_ids(%User{id: user_id}, %MediaItem{id: media_item_id}) do
    from(w in EpisodeWatch,
      where: w.user_id == ^user_id and w.media_item_id == ^media_item_id,
      select: w.episode_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def mark_episode(%User{} = user, %Episode{} = episode, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      episode_id: episode.id,
      media_item_id: episode.media_item_id,
      watched_on: Date.utc_today()
    }

    %EpisodeWatch{}
    |> EpisodeWatch.changeset(Map.merge(defaults, attrs))
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :episode_id])

    after_change(user, episode.media_item_id, {:episode_watched, episode})
  end

  def unmark_episode(%User{id: user_id} = user, %Episode{} = episode) do
    Repo.delete_all(
      from w in EpisodeWatch, where: w.user_id == ^user_id and w.episode_id == ^episode.id
    )

    after_change(user, episode.media_item_id, {:episode_unwatched, episode})
  end

  def mark_season(%User{} = user, %MediaItem{} = media_item, season_number) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    today = Date.utc_today()

    rows =
      from(e in Episode,
        where: e.media_item_id == ^media_item.id and e.season_number == ^season_number,
        select: e.id
      )
      |> Repo.all()
      |> Enum.map(
        &%{
          id: Ecto.UUID.generate(),
          user_id: user.id,
          episode_id: &1,
          media_item_id: media_item.id,
          watched_on: today,
          inserted_at: now,
          updated_at: now
        }
      )

    Repo.insert_all(EpisodeWatch, rows,
      on_conflict: :nothing,
      conflict_target: [:user_id, :episode_id]
    )

    after_change(user, media_item.id, {:episodes_changed, season_number})
  end

  def unmark_season(%User{id: user_id} = user, %MediaItem{} = media_item, season_number) do
    episode_ids =
      from(e in Episode,
        where: e.media_item_id == ^media_item.id and e.season_number == ^season_number,
        select: e.id
      )

    Repo.delete_all(
      from w in EpisodeWatch,
        where: w.user_id == ^user_id and w.episode_id in subquery(episode_ids)
    )

    after_change(user, media_item.id, {:episodes_changed, season_number})
  end

  def episode_progress(%User{id: user_id}, %MediaItem{id: media_item_id}),
    do: user_id |> progress_for([media_item_id]) |> Map.fetch!(media_item_id)

  def season_progress(%User{id: user_id}, %MediaItem{id: media_item_id}, season_number) do
    watched =
      Repo.one(
        from w in EpisodeWatch,
          join: e in Episode,
          on: e.id == w.episode_id,
          where:
            w.user_id == ^user_id and e.media_item_id == ^media_item_id and
              e.season_number == ^season_number,
          select: count(w.id)
      )

    total =
      Repo.one(
        from e in Episode,
          where: e.media_item_id == ^media_item_id and e.season_number == ^season_number,
          select: count(e.id)
      )

    %{watched: watched, total: total}
  end

  def current_seasons(_user_id, []), do: %{}

  def current_seasons(user_id, media_item_ids) do
    from(w in EpisodeWatch,
      join: e in assoc(w, :episode),
      where: w.user_id == ^user_id and w.media_item_id in ^media_item_ids,
      group_by: w.media_item_id,
      select: {w.media_item_id, max(e.season_number)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def progress_for(_user_id, []), do: %{}

  def progress_for(user_id, media_item_ids) do
    watched = count_by_media_item(watched_query(user_id, media_item_ids))
    total = count_by_media_item(total_query(media_item_ids))

    Map.new(media_item_ids, fn id ->
      {id, %{watched: Map.get(watched, id, 0), total: Map.get(total, id, 0)}}
    end)
  end

  defp watched_query(user_id, media_item_ids) do
    from(w in EpisodeWatch,
      where: w.user_id == ^user_id and w.media_item_id in ^media_item_ids,
      group_by: w.media_item_id,
      select: {w.media_item_id, count(w.id)}
    )
  end

  defp total_query(media_item_ids) do
    from(e in Episode,
      where: e.media_item_id in ^media_item_ids and e.season_number >= 1,
      group_by: e.media_item_id,
      select: {e.media_item_id, count(e.id)}
    )
  end

  defp count_by_media_item(query), do: query |> Repo.all() |> Map.new()

  def derive_show_status(%User{} = user, media_item_id) do
    watched = watched_count(user.id, media_item_id)
    aired = aired_count(media_item_id)

    status =
      cond do
        watched == 0 -> nil
        aired > 0 and watched >= aired -> :completed
        true -> :watching
      end

    if status, do: Entries.upsert_entry(user, %MediaItem{id: media_item_id}, %{status: status})
  end

  defp after_change(user, media_item_id, media_message) do
    derive_show_status(user, media_item_id)
    Broadcast.media(media_item_id, media_message)
    Broadcast.activity(user.id, media_message)
    :ok
  end

  defp watched_count(user_id, media_item_id) do
    Repo.one(
      from w in EpisodeWatch,
        where: w.user_id == ^user_id and w.media_item_id == ^media_item_id,
        select: count(w.id)
    )
  end

  defp aired_count(media_item_id) do
    today = Date.utc_today()

    Repo.one(
      from e in Episode,
        where:
          e.media_item_id == ^media_item_id and e.season_number >= 1 and e.air_date <= ^today,
        select: count(e.id)
    )
  end
end
