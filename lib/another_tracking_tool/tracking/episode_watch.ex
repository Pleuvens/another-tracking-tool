defmodule AnotherTrackingTool.Tracking.EpisodeWatch do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.{Episode, MediaItem}

  schema "episode_watches" do
    field :watched_on, :date

    belongs_to :user, User
    belongs_to :episode, Episode
    belongs_to :media_item, MediaItem

    timestamps()
  end

  def changeset(episode_watch, attrs) do
    episode_watch
    |> cast(attrs, [:user_id, :episode_id, :media_item_id, :watched_on])
    |> validate_required([:user_id, :episode_id, :media_item_id])
    |> unique_constraint([:user_id, :episode_id])
  end
end
