defmodule AnotherTrackingTool.Imports.YamtrackTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.Imports.Yamtrack

  @csv """
  media_id,source,media_type,title,image,season_number,episode_number,score,status,notes,start_date,end_date,progress
  603,tmdb,movie,The Matrix,,,,8,Completed,,,2024-01-15,
  27205,tmdb,movie,Inception,,,,,Planning,,,,
  1399,tmdb,tv,Game of Thrones,,,,9,Completed,,,,
  5114,mal,anime,Fullmetal Alchemist,,,,10,Completed,,,,
  """

  test "keeps only tmdb movie rows and normalizes them" do
    assert {:ok, rows} = Yamtrack.parse(@csv)
    assert [matrix, inception] = rows

    assert matrix == %{
             tmdb_id: 603,
             kind: :movie,
             status: :completed,
             rating: 4,
             watched_on: ~D[2024-01-15],
             title: "The Matrix"
           }

    assert inception.tmdb_id == 27205
    assert inception.status == :planned
    assert inception.rating == nil
    assert inception.watched_on == nil
  end

  test "implements the Source behaviour" do
    assert Yamtrack.slug() == :yamtrack
    assert Yamtrack.name() == "Yamtrack"
  end

  test "returns an error on garbage input" do
    assert {:ok, []} = Yamtrack.parse("")
  end
end
