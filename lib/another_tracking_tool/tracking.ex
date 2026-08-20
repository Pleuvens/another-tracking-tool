defmodule AnotherTrackingTool.Tracking do
  @moduledoc "Watch entries and comments on media items, broadcast live to the circle."

  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.{Episode, MediaItem}
  alias AnotherTrackingTool.Tracking.{Comment, EpisodeWatch, WatchEntry}
  alias AnotherTrackingTool.Repo

  @pubsub AnotherTrackingTool.PubSub
  @activity_topic "activity"

  def subscribe(%MediaItem{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  def subscribe_activity, do: Phoenix.PubSub.subscribe(@pubsub, @activity_topic)

  @insert_chunk 1_000

  def import_entries(%User{id: user_id}, entries) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries
    |> Enum.uniq_by(& &1.media_item_id)
    |> Enum.map(&entry_row(&1, user_id, now))
    |> Enum.chunk_every(@insert_chunk)
    |> Enum.reduce(0, fn chunk, total ->
      {count, _} =
        Repo.insert_all(WatchEntry, chunk,
          on_conflict: {:replace, [:status, :rating, :watched_on, :source, :updated_at]},
          conflict_target: [:user_id, :media_item_id]
        )

      total + count
    end)
  end

  defp entry_row(entry, user_id, now) do
    %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      media_item_id: entry.media_item_id,
      status: entry.status,
      rating: entry.rating,
      watched_on: entry.watched_on,
      source: :import,
      inserted_at: now,
      updated_at: now
    }
  end

  def watchlist(%User{id: user_id}) do
    Repo.all(
      from e in WatchEntry,
        where: e.user_id == ^user_id and e.status == :planned,
        order_by: [desc: e.updated_at],
        preload: [:media_item]
    )
  end

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
        at: entry_at(e),
        user: e.user,
        media_item: e.media_item,
        status: e.status,
        rating: e.rating,
        watched_on: e.watched_on
      }
    end)
  end

  defp entry_at(%{watched_on: %Date{} = date}), do: DateTime.new!(date, ~T[00:00:00])
  defp entry_at(%{updated_at: updated_at}), do: updated_at

  defp episode_activity(limit) do
    from(w in EpisodeWatch,
      order_by: [desc: w.inserted_at],
      limit: ^limit,
      preload: [:user, :media_item, :episode]
    )
    |> Repo.all()
    |> Enum.map(fn w ->
      %{
        type: :episode,
        at: w.inserted_at,
        user: w.user,
        media_item: w.media_item,
        episode: w.episode
      }
    end)
  end

  def get_entry(%User{id: user_id}, %MediaItem{id: media_item_id}),
    do: Repo.get_by(WatchEntry, user_id: user_id, media_item_id: media_item_id)

  def upsert_entry(%User{} = user, %MediaItem{} = media_item, attrs) do
    entry =
      get_entry(user, media_item) ||
        %WatchEntry{user_id: user.id, media_item_id: media_item.id}

    with {:ok, entry} <- entry |> WatchEntry.changeset(attrs) |> Repo.insert_or_update() do
      broadcast(media_item.id, {:entry_upserted, entry})
      Phoenix.PubSub.broadcast(@pubsub, @activity_topic, {:activity, entry})
      {:ok, entry}
    end
  end

  def set_status(user, media_item, status),
    do: upsert_entry(user, media_item, %{status: status})

  def mark_watched(user, media_item, attrs \\ %{}),
    do: upsert_entry(user, media_item, Map.merge(%{status: :completed}, attrs))

  def rate(user, media_item, rating) do
    base = if get_entry(user, media_item), do: %{}, else: %{status: :completed}
    upsert_entry(user, media_item, Map.put(base, :rating, rating))
  end

  def delete_entry(%User{} = user, %MediaItem{} = media_item) do
    case get_entry(user, media_item) do
      nil ->
        {:ok, nil}

      entry ->
        {:ok, entry} = Repo.delete(entry)
        broadcast(media_item.id, {:entry_deleted, entry})
        {:ok, entry}
    end
  end

  def for_media_item(%MediaItem{id: id}) do
    Repo.all(
      from e in WatchEntry,
        where: e.media_item_id == ^id,
        order_by: [desc: e.updated_at],
        preload: [:user]
    )
  end

  def circle_rating(%MediaItem{id: id}) do
    avg =
      Repo.one(
        from e in WatchEntry,
          where: e.media_item_id == ^id and not is_nil(e.rating),
          select: avg(e.rating)
      )

    if avg, do: avg |> Decimal.to_float() |> Float.round(1)
  end

  def list_comments(%MediaItem{id: id}) do
    Repo.all(
      from c in Comment,
        where: c.media_item_id == ^id,
        order_by: [asc: c.inserted_at],
        preload: [:user]
    )
  end

  def create_comment(%User{id: user_id}, %MediaItem{} = media_item, body) do
    result =
      %Comment{}
      |> Comment.changeset(%{user_id: user_id, media_item_id: media_item.id, body: body})
      |> Repo.insert()

    with {:ok, comment} <- result do
      comment = Repo.preload(comment, :user)
      broadcast(media_item.id, {:comment_created, comment})
      {:ok, comment}
    end
  end

  def delete_comment(%Comment{user_id: user_id} = comment, %User{id: user_id}) do
    {:ok, comment} = Repo.delete(comment)
    broadcast(comment.media_item_id, {:comment_deleted, comment})
    {:ok, comment}
  end

  def delete_comment(%Comment{}, %User{}), do: {:error, :unauthorized}

  def watched_episode_ids(%User{id: user_id}, %MediaItem{id: media_item_id}) do
    from(w in EpisodeWatch,
      where: w.user_id == ^user_id and w.media_item_id == ^media_item_id,
      select: w.episode_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def mark_episode(%User{} = user, %Episode{} = episode) do
    %EpisodeWatch{}
    |> EpisodeWatch.changeset(%{
      user_id: user.id,
      episode_id: episode.id,
      media_item_id: episode.media_item_id,
      watched_on: Date.utc_today()
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :episode_id])

    after_episode_change(user, episode.media_item_id, {:episode_watched, episode})
  end

  def unmark_episode(%User{id: user_id} = user, %Episode{} = episode) do
    Repo.delete_all(
      from w in EpisodeWatch, where: w.user_id == ^user_id and w.episode_id == ^episode.id
    )

    after_episode_change(user, episode.media_item_id, {:episode_unwatched, episode})
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

    after_episode_change(user, media_item.id, {:episodes_changed, season_number})
  end

  def episode_progress(%User{id: user_id}, %MediaItem{id: media_item_id}) do
    %{
      watched: watched_episode_count(user_id, media_item_id),
      total: total_episode_count(media_item_id)
    }
  end

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

  defp after_episode_change(user, media_item_id, media_message) do
    derive_show_status(user, media_item_id)
    broadcast(media_item_id, media_message)
    Phoenix.PubSub.broadcast(@pubsub, @activity_topic, {:activity, media_message})
    :ok
  end

  defp derive_show_status(%User{} = user, media_item_id) do
    watched = watched_episode_count(user.id, media_item_id)
    aired = aired_episode_count(media_item_id)

    status =
      cond do
        watched == 0 -> nil
        aired > 0 and watched >= aired -> :completed
        true -> :watching
      end

    if status, do: upsert_entry(user, %MediaItem{id: media_item_id}, %{status: status})
  end

  defp watched_episode_count(user_id, media_item_id) do
    Repo.one(
      from w in EpisodeWatch,
        where: w.user_id == ^user_id and w.media_item_id == ^media_item_id,
        select: count(w.id)
    )
  end

  defp total_episode_count(media_item_id) do
    Repo.one(
      from e in Episode,
        where: e.media_item_id == ^media_item_id and e.season_number >= 1,
        select: count(e.id)
    )
  end

  defp aired_episode_count(media_item_id) do
    today = Date.utc_today()

    Repo.one(
      from e in Episode,
        where:
          e.media_item_id == ^media_item_id and e.season_number >= 1 and e.air_date <= ^today,
        select: count(e.id)
    )
  end

  defp broadcast(media_item_id, message),
    do: Phoenix.PubSub.broadcast(@pubsub, topic(media_item_id), message)

  defp topic(media_item_id), do: "media:#{media_item_id}"
end
