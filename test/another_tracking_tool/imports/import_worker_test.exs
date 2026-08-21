defmodule AnotherTrackingTool.Imports.ImportWorkerTest do
  use AnotherTrackingTool.DataCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.{Catalog, Imports, Tracking}
  alias AnotherTrackingTool.Imports.ImportWorker
  alias AnotherTrackingTool.TmdbStub

  setup do
    %{user: user_fixture()}
  end

  defp rows do
    [
      %{
        "kind" => "movie",
        "tmdb_id" => 603,
        "title" => "The Matrix",
        "status" => "completed",
        "rating" => 4,
        "watched_on" => "2024-01-15"
      },
      %{
        "kind" => "movie",
        "tmdb_id" => 999,
        "title" => "Ghost",
        "status" => "planned",
        "rating" => nil,
        "watched_on" => nil
      }
    ]
  end

  test "fetches resolvable titles, writes entries, skips misses, reports done", %{user: user} do
    TmdbStub.stub([
      {"/3/movie/603", %{"id" => 603, "title" => "The Matrix", "overview" => "..."}}
    ])

    Imports.subscribe(user)

    assert :ok = perform_job(ImportWorker, %{"user_id" => user.id, "rows" => rows()})

    matrix = Catalog.get_by_external(:tmdb, 603, kind: :movie)
    entry = Tracking.get_entry(user, matrix)
    assert entry.status == :completed
    assert entry.rating == 4
    assert entry.watched_on == ~D[2024-01-15]
    assert entry.source == :import

    # the unresolvable row creates no watch entry
    assert Repo.aggregate(Tracking.WatchEntry, :count) == 1
    assert_receive {:import_progress, %{done: _, total: 2}}
    assert_receive {:import_done, %{imported: 1, skipped: 1, total: 2}}
  end

  test "imports TV episode rows as episode watches and derives status", %{user: user} do
    TmdbStub.stub([
      {"/3/tv/1399",
       %{
         "id" => 1399,
         "name" => "GoT",
         "seasons" => [%{"season_number" => 1, "episode_count" => 1}]
       }},
      {"/3/tv/1399/season/1",
       %{
         "episodes" => [
           %{"season_number" => 1, "episode_number" => 1, "air_date" => "2011-04-17"}
         ]
       }}
    ])

    rows = [
      %{
        "kind" => "episode",
        "tmdb_id" => 1399,
        "season_number" => 1,
        "episode_number" => 1,
        "title" => "GoT",
        "watched_on" => "2023-05-21"
      }
    ]

    assert :ok = perform_job(ImportWorker, %{"user_id" => user.id, "rows" => rows})

    show = Catalog.get_by_external(:tmdb, 1399, kind: :tv)
    assert Tracking.episode_progress(user, show) == %{watched: 1, total: 1}
    assert Tracking.get_entry(user, show).status == :completed
  end

  test "imports a show rating from a tv row while deriving status from episodes", %{user: user} do
    TmdbStub.stub([
      {"/3/tv/1399",
       %{
         "id" => 1399,
         "name" => "GoT",
         "seasons" => [%{"season_number" => 1, "episode_count" => 2}]
       }},
      {"/3/tv/1399/season/1",
       %{
         "episodes" =>
           for(n <- 1..2,
               do: %{"season_number" => 1, "episode_number" => n, "air_date" => "2011-04-17"})
       }}
    ])

    rows = [
      %{
        "kind" => "show",
        "tmdb_id" => 1399,
        "status" => "watching",
        "rating" => 5,
        "watched_on" => "2023-05-21",
        "title" => "GoT"
      },
      %{
        "kind" => "season",
        "tmdb_id" => 1399,
        "season_number" => 1,
        "progress" => 2,
        "title" => "GoT",
        "watched_on" => "2023-05-21"
      }
    ]

    assert :ok = perform_job(ImportWorker, %{"user_id" => user.id, "rows" => rows})

    show = Catalog.get_by_external(:tmdb, 1399, kind: :tv)
    entry = Tracking.get_entry(user, show)
    assert entry.rating == 5
    assert entry.status == :completed
  end

  test "expands a season row into episode watches for 1..progress", %{user: user} do
    TmdbStub.stub([
      {"/3/tv/1399",
       %{
         "id" => 1399,
         "name" => "GoT",
         "seasons" => [%{"season_number" => 1, "episode_count" => 3}]
       }},
      {"/3/tv/1399/season/1",
       %{
         "episodes" =>
           for(n <- 1..3, do: %{"season_number" => 1, "episode_number" => n, "air_date" => nil})
       }}
    ])

    rows = [
      %{
        "kind" => "season",
        "tmdb_id" => 1399,
        "season_number" => 1,
        "progress" => 2,
        "title" => "GoT",
        "watched_on" => "2023-05-21"
      }
    ]

    assert :ok = perform_job(ImportWorker, %{"user_id" => user.id, "rows" => rows})

    show = Catalog.get_by_external(:tmdb, 1399, kind: :tv)
    assert Tracking.episode_progress(user, show) == %{watched: 2, total: 3}
  end

  test "re-running is idempotent", %{user: user} do
    TmdbStub.stub([{"/3/movie/603", %{"id" => 603, "title" => "The Matrix"}}])

    args = %{"user_id" => user.id, "rows" => [Enum.at(rows(), 0)]}
    assert :ok = perform_job(ImportWorker, args)
    assert :ok = perform_job(ImportWorker, args)

    assert Repo.aggregate(Tracking.WatchEntry, :count) == 1
  end
end
