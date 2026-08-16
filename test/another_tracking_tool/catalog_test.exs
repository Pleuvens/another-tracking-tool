defmodule AnotherTrackingTool.CatalogTest do
  use AnotherTrackingTool.DataCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.{EnrichMediaItemWorker, MediaItem}
  alias AnotherTrackingTool.TmdbStub

  defp enriched_at, do: DateTime.utc_now() |> DateTime.truncate(:second)

  describe "search/2" do
    test "persists cinema results and skips people" do
      TmdbStub.stub([
        {"/3/search/multi",
         %{
           "results" => [
             %{"media_type" => "movie", "id" => 603, "title" => "Matrix", "popularity" => 9.0},
             %{"media_type" => "person", "id" => 1, "name" => "Keanu"}
           ]
         }}
      ])

      assert {:ok, [item]} = Catalog.search("matrix")
      assert item.kind == :movie
      assert item.tmdb_id == 603
      assert item.title_fr == "Matrix"
    end

    test "schedules enrichment for its results" do
      TmdbStub.stub([
        {"/3/search/multi",
         %{"results" => [%{"media_type" => "movie", "id" => 603, "title" => "Matrix"}]}}
      ])

      assert {:ok, [item]} = Catalog.search("matrix")
      assert_enqueued(worker: EnrichMediaItemWorker, args: %{media_item_id: item.id})
    end
  end

  describe "upsert_media_item/1" do
    test "is idempotent by (kind, tmdb_id) and refreshes shell fields" do
      {:ok, a} =
        Catalog.upsert_media_item(%{source: :tmdb, source_id: 603, kind: :movie, title_fr: "A"})

      {:ok, b} =
        Catalog.upsert_media_item(%{source: :tmdb, source_id: 603, kind: :movie, title_fr: "B"})

      assert a.id == b.id
      assert b.title_fr == "B"
      assert Repo.aggregate(MediaItem, :count) == 1
    end

    test "a later shell upsert does not clobber enriched fields" do
      {:ok, item} =
        Catalog.upsert_media_item(%{source: :tmdb, source_id: 7, kind: :movie, title_fr: "A"})

      {:ok, _} =
        Catalog.update_media_item(item, %{title_en: "A-en", details_synced_at: enriched_at()})

      {:ok, _} =
        Catalog.upsert_media_item(%{source: :tmdb, source_id: 7, kind: :movie, title_fr: "A2"})

      reloaded = Repo.get_by!(MediaItem, tmdb_id: 7)
      assert reloaded.title_fr == "A2"
      assert reloaded.title_en == "A-en"
      refute is_nil(reloaded.details_synced_at)
    end
  end

  describe "get_by_external/3" do
    test "looks up by the source-routed column" do
      item = media_item_fixture(%{source_id: 42, kind: :movie})
      assert Catalog.get_by_external(:tmdb, 42, kind: :movie).id == item.id
      assert Catalog.get_by_external(:tmdb, 999) == nil
    end
  end

  describe "ensure_details/1" do
    test "enqueues enrichment for a shell" do
      shell = media_item_fixture()
      assert {:ok, _} = Catalog.ensure_details(shell)
      assert_enqueued(worker: EnrichMediaItemWorker, args: %{media_item_id: shell.id})
    end

    test "is a no-op once enriched" do
      {:ok, enriched} =
        media_item_fixture() |> Catalog.update_media_item(%{details_synced_at: enriched_at()})

      assert {:ok, _} = Catalog.ensure_details(enriched)
      refute_enqueued(worker: EnrichMediaItemWorker)
    end
  end
end
