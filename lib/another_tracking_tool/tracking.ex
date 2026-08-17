defmodule AnotherTrackingTool.Tracking do
  @moduledoc "Watch entries and comments on media items, broadcast live to the circle."

  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Tracking.{Comment, WatchEntry}
  alias AnotherTrackingTool.Repo

  @pubsub AnotherTrackingTool.PubSub

  def subscribe(%MediaItem{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  def get_entry(%User{id: user_id}, %MediaItem{id: media_item_id}),
    do: Repo.get_by(WatchEntry, user_id: user_id, media_item_id: media_item_id)

  def upsert_entry(%User{} = user, %MediaItem{} = media_item, attrs) do
    entry =
      get_entry(user, media_item) ||
        %WatchEntry{user_id: user.id, media_item_id: media_item.id}

    with {:ok, entry} <- entry |> WatchEntry.changeset(attrs) |> Repo.insert_or_update() do
      broadcast(media_item.id, {:entry_upserted, entry})
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

  defp broadcast(media_item_id, message),
    do: Phoenix.PubSub.broadcast(@pubsub, topic(media_item_id), message)

  defp topic(media_item_id), do: "media:#{media_item_id}"
end
