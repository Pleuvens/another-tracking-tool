defmodule AnotherTrackingTool.Providers.Tmdb.SeedWorkerTest do
  use AnotherTrackingTool.DataCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.{EnrichMediaItemWorker, MediaItem}
  alias AnotherTrackingTool.Providers.Tmdb.SeedWorker
  alias AnotherTrackingTool.TmdbStub

  defp trending(results), do: TmdbStub.stub([{"/3/trending/all/week", %{"results" => results}}])

  test "seeds fresh entries and enqueues enrichment plus the next page" do
    trending([%{"media_type" => "movie", "id" => 603, "title" => "Matrix"}])

    assert :ok = perform_job(SeedWorker, %{"source" => "trending", "page" => 1})

    item = Repo.one(MediaItem)
    assert item.tmdb_id == 603
    assert_enqueued(worker: EnrichMediaItemWorker, args: %{media_item_id: item.id})

    assert_enqueued(
      worker: SeedWorker,
      args: %{"source" => "trending", "page" => 2, "remaining" => 19}
    )
  end

  test "skips already-enriched entries and stops when a page has nothing new" do
    enriched =
      media_item_fixture(%{kind: :movie, source_id: 603})
      |> then(fn item ->
        {:ok, item} =
          Catalog.update_media_item(item, %{
            details_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })

        item
      end)

    trending([%{"media_type" => "movie", "id" => enriched.tmdb_id, "title" => "Matrix"}])

    assert :ok = perform_job(SeedWorker, %{"source" => "trending", "page" => 1})
    refute_enqueued(worker: EnrichMediaItemWorker)
    refute_enqueued(worker: SeedWorker)
  end

  test "respects the remaining budget" do
    trending([
      %{"media_type" => "movie", "id" => 1, "title" => "A"},
      %{"media_type" => "movie", "id" => 2, "title" => "B"}
    ])

    assert :ok = perform_job(SeedWorker, %{"source" => "trending", "page" => 1, "remaining" => 1})

    assert Repo.aggregate(MediaItem, :count) == 1
    refute_enqueued(worker: SeedWorker)
  end
end
