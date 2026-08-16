defmodule AnotherTrackingTool.Catalog.Episode do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Catalog.{MediaItem, Season}

  schema "episodes" do
    field :tmdb_id, :integer
    field :season_number, :integer
    field :episode_number, :integer
    field :name, :string
    field :overview, :string
    field :air_date, :date
    field :still_path, :string
    field :runtime, :integer

    belongs_to :media_item, MediaItem
    belongs_to :season, Season

    timestamps()
  end

  @castable ~w(tmdb_id season_number episode_number name overview air_date still_path runtime
    media_item_id season_id)a

  def changeset(episode, attrs) do
    episode
    |> cast(attrs, @castable)
    |> validate_required([:media_item_id, :season_id, :season_number, :episode_number])
    |> unique_constraint([:media_item_id, :season_number, :episode_number])
  end
end
