defmodule AnotherTrackingTool.Providers.TmdbTest do
  use AnotherTrackingTool.DataCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Catalog.{Episode, Season, TmdbGenre}
  alias AnotherTrackingTool.Providers.Tmdb
  alias AnotherTrackingTool.Providers.Tmdb.SyncSeasonWorker
  alias AnotherTrackingTool.TmdbStub

  describe "enrich/1 (movie)" do
    test "fills details, external ids, and links genres" do
      item = media_item_fixture(%{kind: :movie, source_id: 603})

      TmdbStub.stub([
        {"/3/movie/603",
         %{
           "id" => 603,
           "title" => "Matrix",
           "overview" => "Un hacker...",
           "genres" => [%{"id" => 28, "name" => "Action"}],
           "external_ids" => %{"imdb_id" => "tt0133093"}
         }}
      ])

      assert {:ok, enriched} = Tmdb.enrich(item)
      assert enriched.overview_fr == "Un hacker..."
      assert enriched.imdb_id == "tt0133093"
      refute is_nil(enriched.details_synced_at)

      enriched = Repo.preload(enriched, :tmdb_genres)
      assert [%TmdbGenre{tmdb_id: 28, name_fr: "Action"}] = enriched.tmdb_genres
    end

    test "falls back to English when the French overview is blank" do
      item = media_item_fixture(%{kind: :movie, source_id: 603})

      TmdbStub.stub([
        {{"/3/movie/603", "fr-FR"}, %{"id" => 603, "title" => "Matrix", "overview" => ""}},
        {{"/3/movie/603", "en-US"},
         %{"id" => 603, "title" => "The Matrix", "overview" => "A hacker..."}}
      ])

      assert {:ok, enriched} = Tmdb.enrich(item)
      assert enriched.overview_fr == nil
      assert enriched.title_en == "The Matrix"
      assert enriched.overview_en == "A hacker..."
    end
  end

  describe "enrich/1 (tv)" do
    test "upserts season shells and fans out a job per season" do
      item = media_item_fixture(%{kind: :tv, source_id: 1399})

      TmdbStub.stub([
        {"/3/tv/1399",
         %{
           "id" => 1399,
           "name" => "Game of Thrones",
           "overview" => "Des familles...",
           "seasons" => [
             %{"id" => 1, "season_number" => 1, "name" => "Saison 1", "episode_count" => 10},
             %{"id" => 2, "season_number" => 2, "name" => "Saison 2", "episode_count" => 10}
           ]
         }}
      ])

      assert {:ok, _} = Tmdb.enrich(item)
      assert Repo.aggregate(Season, :count) == 2
      assert_enqueued(worker: SyncSeasonWorker, args: %{media_item_id: item.id, season_number: 1})
      assert_enqueued(worker: SyncSeasonWorker, args: %{media_item_id: item.id, season_number: 2})
    end
  end

  describe "sync_season/2" do
    test "upserts the season's episodes" do
      item = media_item_fixture(%{kind: :tv, source_id: 1399})
      season_fixture(item, %{season_number: 1})

      TmdbStub.stub([
        {"/3/tv/1399/season/1",
         %{
           "episodes" => [
             %{"id" => 10, "season_number" => 1, "episode_number" => 1, "name" => "Pilot"},
             %{"id" => 11, "season_number" => 1, "episode_number" => 2, "name" => "Ep2"}
           ]
         }}
      ])

      assert :ok = Tmdb.sync_season(item, 1)
      assert Repo.aggregate(Episode, :count) == 2
    end
  end

  describe "show_id_for_tvdb_episode/1" do
    test "returns the show's tmdb id for a known tvdb episode id" do
      TmdbStub.stub([
        {"/3/find/7839618", %{"tv_episode_results" => [%{"show_id" => 97_546}]}}
      ])

      assert {:ok, 97_546} = Tmdb.show_id_for_tvdb_episode(7_839_618)
    end

    test "returns not_found when tmdb has no match" do
      TmdbStub.stub([{"/3/find/0", %{"tv_episode_results" => []}}])

      assert {:error, :not_found} = Tmdb.show_id_for_tvdb_episode(0)
    end
  end

  describe "sync_genres/0" do
    test "merges FR and EN names onto one row per genre" do
      TmdbStub.stub([
        {{"/3/genre/movie/list", "fr-FR"}, %{"genres" => [%{"id" => 28, "name" => "Action"}]}},
        {{"/3/genre/tv/list", "fr-FR"}, %{"genres" => [%{"id" => 16, "name" => "Animation"}]}},
        {{"/3/genre/movie/list", "en-US"}, %{"genres" => [%{"id" => 28, "name" => "Action"}]}},
        {{"/3/genre/tv/list", "en-US"}, %{"genres" => [%{"id" => 16, "name" => "Animation"}]}}
      ])

      assert :ok = Tmdb.sync_genres()
      action = Repo.get_by!(TmdbGenre, tmdb_id: 28)
      assert action.name_fr == "Action"
      assert action.name_en == "Action"
      assert Repo.aggregate(TmdbGenre, :count) == 2
    end
  end
end
