defmodule AnotherTrackingTool.Catalog.TmdbGenre do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  schema "tmdb_genres" do
    field :tmdb_id, :integer
    field :name_fr, :string
    field :name_en, :string

    timestamps()
  end

  def changeset(genre, attrs) do
    genre
    |> cast(attrs, [:tmdb_id, :name_fr, :name_en])
    |> validate_required([:tmdb_id])
    |> unique_constraint(:tmdb_id)
  end
end
