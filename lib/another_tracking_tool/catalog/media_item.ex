defmodule AnotherTrackingTool.Catalog.MediaItem do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Catalog.{Episode, Season, TmdbGenre}
  alias AnotherTrackingTool.MediaEnums

  schema "media_items" do
    field :kind, Ecto.Enum, values: MediaEnums.kinds()
    field :tmdb_id, :integer
    field :imdb_id, :string
    field :tvdb_id, :integer
    field :mal_id, :integer
    field :anilist_id, :integer
    field :original_title, :string
    field :title_fr, :string
    field :title_en, :string
    field :overview_fr, :string
    field :overview_en, :string
    field :poster_path, :string
    field :backdrop_path, :string
    field :released_on, :date
    field :original_language, :string
    field :tmdb_popularity, :float
    field :tmdb_vote_average, :float
    field :tmdb_vote_count, :integer
    field :details_synced_at, :utc_datetime

    many_to_many :tmdb_genres, TmdbGenre,
      join_through: "media_item_tmdb_genres",
      on_replace: :delete

    has_many :seasons, Season
    has_many :episodes, Episode

    timestamps()
  end

  @castable ~w(kind tmdb_id imdb_id tvdb_id mal_id anilist_id original_title title_fr
    title_en overview_fr overview_en poster_path backdrop_path released_on original_language
    tmdb_popularity tmdb_vote_average tmdb_vote_count details_synced_at)a

  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, @castable)
    |> validate_required([:kind])
    |> unique_constraint([:kind, :tmdb_id])
  end

  def display_title(%__MODULE__{} = item),
    do: item.title_fr || item.title_en || item.original_title

  def display_overview(%__MODULE__{} = item), do: item.overview_fr || item.overview_en

  def year(%__MODULE__{released_on: %Date{year: year}}), do: year
  def year(%__MODULE__{}), do: nil
end
