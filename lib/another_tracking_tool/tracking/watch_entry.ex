defmodule AnotherTrackingTool.Tracking.WatchEntry do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.{WatchSources, WatchStatuses}

  schema "watch_entries" do
    field :status, Ecto.Enum, values: WatchStatuses.all()
    field :rating, :integer
    field :watched_on, :date
    field :source, Ecto.Enum, values: WatchSources.all(), default: WatchSources.default()

    belongs_to :user, User
    belongs_to :media_item, MediaItem

    timestamps()
  end

  @castable ~w(status rating watched_on source user_id media_item_id)a

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @castable)
    |> validate_required([:user_id, :media_item_id, :status])
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> unique_constraint([:user_id, :media_item_id])
  end
end
