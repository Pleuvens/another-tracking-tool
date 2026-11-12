defmodule AnotherTrackingTool.Tracking.Entries do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Broadcast, WatchEntry}

  def watchlist(%User{id: user_id}) do
    Repo.all(
      from e in WatchEntry,
        where: e.user_id == ^user_id and e.status == :planned,
        order_by: [desc: e.updated_at],
        preload: [:media_item]
    )
  end

  def get_entry(%User{id: user_id}, %MediaItem{id: media_item_id}),
    do: Repo.get_by(WatchEntry, user_id: user_id, media_item_id: media_item_id)

  def upsert_entry(%User{} = user, %MediaItem{} = media_item, attrs) do
    entry =
      get_entry(user, media_item) ||
        %WatchEntry{user_id: user.id, media_item_id: media_item.id}

    with {:ok, entry} <- entry |> WatchEntry.changeset(attrs) |> Repo.insert_or_update() do
      Broadcast.media(media_item.id, {:entry_upserted, entry})
      Broadcast.activity(user.id, entry)
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
        Broadcast.media(media_item.id, {:entry_deleted, entry})
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
end
