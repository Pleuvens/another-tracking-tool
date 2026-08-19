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
        "tmdb_id" => 603,
        "title" => "The Matrix",
        "status" => "completed",
        "rating" => 4,
        "watched_on" => "2024-01-15"
      },
      %{
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

  test "re-running is idempotent", %{user: user} do
    TmdbStub.stub([{"/3/movie/603", %{"id" => 603, "title" => "The Matrix"}}])

    args = %{"user_id" => user.id, "rows" => [Enum.at(rows(), 0)]}
    assert :ok = perform_job(ImportWorker, args)
    assert :ok = perform_job(ImportWorker, args)

    assert Repo.aggregate(Tracking.WatchEntry, :count) == 1
  end
end
