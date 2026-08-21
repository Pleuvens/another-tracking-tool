defmodule AnotherTrackingTool.Imports.YamtrackTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.Imports.Yamtrack

  @csv """
  "media_id","source","media_type","title","image","season_number","episode_number","score","status","notes","start_date","end_date","progress","created_at","progressed_at"
  "603","tmdb","movie","The Matrix","https://img/m.jpg","","","8","Completed","","","2024-01-15 22:00:00+00:00","0","2026-07-13 00:49:07+00:00","2024-01-15 22:00:00+00:00"
  "27205","tmdb","movie","Inception","https://img/i.jpg","","","","Planning","","","","0","2026-07-13 00:49:07+00:00",""
  "1399","tmdb","tv","Game of Thrones","https://img/g.jpg","","","9","Completed","","","2023-05-21 22:00:00+00:00","73","2026-07-13 00:49:07+00:00","2023-05-21 22:00:00+00:00"
  "5114","mal","anime","Fullmetal Alchemist","https://img/f.jpg","","","10","Completed","","","","0","2026-07-13 00:49:07+00:00",""
  """

  test "normalizes tmdb movie and tv rows, ignores other sources, parsing datetime dates" do
    assert {:ok, rows} = Yamtrack.parse(@csv)
    assert [matrix, inception, got] = rows

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

    assert got == %{
             tmdb_id: 1399,
             kind: :show,
             status: :completed,
             rating: 5,
             watched_on: ~D[2023-05-21],
             title: "Game of Thrones"
           }
  end

  @tv_csv """
  "media_id","source","media_type","title","image","season_number","episode_number","score","status","notes","start_date","end_date","progress","created_at","progressed_at"
  "125988","tmdb","season","Silo","https://img/s.jpg","3","","","In progress","","","2026-08-15 14:57:00+00:00","7","2026-08-12 10:51:27+00:00","2026-08-15 14:57:00+00:00"
  "125988","tmdb","episode","Silo","https://img/e.jpg","3","7","","","","","2026-08-15 14:57:00+00:00","1","2026-08-15 14:57:10+00:00","2026-08-15 14:57:10+00:00"
  """

  test "expands season progress into a season row and keeps explicit episode rows" do
    assert {:ok, [season, episode]} = Yamtrack.parse(@tv_csv)

    assert season == %{
             tmdb_id: 125_988,
             kind: :season,
             season_number: 3,
             progress: 7,
             watched_on: ~D[2026-08-15],
             title: "Silo"
           }

    assert episode.kind == :episode
    assert episode.season_number == 3
    assert episode.episode_number == 7
    assert episode.watched_on == ~D[2026-08-15]
  end

  test "implements the Source behaviour" do
    assert Yamtrack.slug() == :yamtrack
    assert Yamtrack.name() == "Yamtrack"
  end

  test "returns an error on garbage input" do
    assert {:ok, []} = Yamtrack.parse("")
  end
end
