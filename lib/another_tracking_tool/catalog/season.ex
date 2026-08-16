defmodule AnotherTrackingTool.Catalog.Season do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Catalog.{Episode, MediaItem}

  schema "seasons" do
    field :tmdb_id, :integer
    field :season_number, :integer
    field :name, :string
    field :overview, :string
    field :air_date, :date
    field :poster_path, :string
    field :episode_count, :integer

    belongs_to :media_item, MediaItem
    has_many :episodes, Episode

    timestamps()
  end

  @castable ~w(tmdb_id season_number name overview air_date poster_path episode_count
    media_item_id)a

  def changeset(season, attrs) do
    season
    |> cast(attrs, @castable)
    |> validate_required([:media_item_id, :season_number])
    |> unique_constraint([:media_item_id, :season_number])
  end
end
