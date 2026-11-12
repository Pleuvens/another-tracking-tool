defmodule AnotherTrackingTool.Tracking.Comments do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Broadcast, Comment}

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
      Broadcast.media(media_item.id, {:comment_created, comment})
      {:ok, comment}
    end
  end

  def delete_comment(%Comment{user_id: user_id} = comment, %User{id: user_id}) do
    {:ok, comment} = Repo.delete(comment)
    Broadcast.media(comment.media_item_id, {:comment_deleted, comment})
    {:ok, comment}
  end

  def delete_comment(%Comment{}, %User{}), do: {:error, :unauthorized}
end
