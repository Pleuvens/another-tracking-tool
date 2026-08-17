defmodule AnotherTrackingTool.Tracking.Comment do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem

  schema "comments" do
    field :body, :string

    belongs_to :user, User
    belongs_to :media_item, MediaItem

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :media_item_id])
    |> validate_required([:body, :user_id, :media_item_id])
    |> validate_length(:body, min: 1, max: 2000)
  end
end
