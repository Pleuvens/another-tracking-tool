defmodule AnotherTrackingTool.TrackingTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures
  import AnotherTrackingTool.TrackingFixtures

  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, WatchEntry}

  setup do
    %{user: user_fixture(), movie: media_item_fixture(%{kind: :movie})}
  end

  defp tv_episode do
    show = media_item_fixture(%{kind: :tv})
    season = season_fixture(show)
    episode_fixture(show, season)
  end

  describe "entries" do
    test "upsert is idempotent per (user, media_item) and preserves fields", ctx do
      %{user: user, movie: movie} = ctx
      {:ok, a} = Tracking.set_status(user, movie, :planned)
      {:ok, b} = Tracking.rate(user, movie, 4)

      assert a.id == b.id
      assert b.rating == 4
      assert Tracking.get_entry(user, movie).status == :planned
      assert Repo.aggregate(WatchEntry, :count) == 1
    end

    test "rate without an entry defaults to completed", %{user: user, movie: movie} do
      {:ok, entry} = Tracking.rate(user, movie, 5)
      assert entry.status == :completed
      assert entry.rating == 5
    end

    test "mark_watched sets completed with the given date", %{user: user, movie: movie} do
      {:ok, entry} = Tracking.mark_watched(user, movie, %{watched_on: ~D[2024-01-01]})
      assert entry.status == :completed
      assert entry.watched_on == ~D[2024-01-01]
    end

    test "rejects an out-of-range rating", %{user: user, movie: movie} do
      assert {:error, changeset} =
               Tracking.upsert_entry(user, movie, %{status: :completed, rating: 9})

      assert %{rating: [_]} = errors_on(changeset)
    end

    test "delete_entry removes it", %{user: user, movie: movie} do
      watch_entry_fixture(user, movie)
      assert {:ok, _} = Tracking.delete_entry(user, movie)
      assert Tracking.get_entry(user, movie) == nil
    end
  end

  describe "episode watches" do
    test "mark_episode defaults to a manual watch today", %{user: user} do
      episode = tv_episode()
      Tracking.mark_episode(user, episode)

      watch = Repo.get_by!(EpisodeWatch, user_id: user.id, episode_id: episode.id)
      assert watch.source == :manual
      assert watch.watched_on == Date.utc_today()
    end

    test "mark_episode records the given source and date", %{user: user} do
      episode = tv_episode()
      Tracking.mark_episode(user, episode, %{source: :plex, watched_on: ~D[2024-02-02]})

      watch = Repo.get_by!(EpisodeWatch, user_id: user.id, episode_id: episode.id)
      assert watch.source == :plex
      assert watch.watched_on == ~D[2024-02-02]
    end
  end

  describe "circle" do
    test "circle_rating averages ratings across users", %{movie: movie} do
      Tracking.rate(user_fixture(), movie, 4)
      Tracking.rate(user_fixture(), movie, 2)
      assert Tracking.circle_rating(movie) == 3.0
    end

    test "circle_rating is nil with no ratings", %{movie: movie} do
      assert Tracking.circle_rating(movie) == nil
    end

    test "for_media_item returns entries with their users", %{user: user, movie: movie} do
      watch_entry_fixture(user, movie)
      assert [entry] = Tracking.for_media_item(movie)
      assert entry.user.id == user.id
    end
  end

  describe "comments" do
    test "create and list chronologically with users", %{user: user, movie: movie} do
      {:ok, _} = Tracking.create_comment(user, movie, "Loved it")
      assert [comment] = Tracking.list_comments(movie)
      assert comment.body == "Loved it"
      assert comment.user.id == user.id
    end

    test "delete_comment only by its author", %{user: user, movie: movie} do
      comment = comment_fixture(user, movie)
      assert {:error, :unauthorized} = Tracking.delete_comment(comment, user_fixture())
      assert {:ok, _} = Tracking.delete_comment(comment, user)
    end
  end

  describe "broadcast" do
    test "entries and comments broadcast on the media topic", %{user: user, movie: movie} do
      Tracking.subscribe(movie)
      {:ok, _} = Tracking.rate(user, movie, 5)
      assert_receive {:entry_upserted, _}
      {:ok, _} = Tracking.create_comment(user, movie, "hi")
      assert_receive {:comment_created, _}
    end

    test "entries broadcast a user-tagged envelope on the activity topic", %{
      user: user,
      movie: movie
    } do
      user_id = user.id
      Tracking.subscribe_activity()
      {:ok, _} = Tracking.set_status(user, movie, :watching)
      assert_receive {:activity, %{user_id: ^user_id, subject: %WatchEntry{}}}
    end

    test "episode watches broadcast the same envelope with the acting user", %{user: user} do
      user_id = user.id
      show = media_item_fixture(%{kind: :tv})
      season = season_fixture(show)
      episode = episode_fixture(show, season)

      Tracking.subscribe_activity()
      Tracking.mark_episode(user, episode)

      assert_receive {:activity, %{user_id: ^user_id, subject: {:episode_watched, _}}}
    end
  end

  describe "watchlist" do
    test "returns only the user's planned entries with media preloaded", ctx do
      %{user: user, movie: movie} = ctx
      other_movie = media_item_fixture(%{kind: :movie})
      {:ok, _} = Tracking.set_status(user, movie, :planned)
      {:ok, _} = Tracking.set_status(user, other_movie, :completed)

      {:ok, _} =
        Tracking.set_status(user_fixture(), media_item_fixture(%{kind: :movie}), :planned)

      assert [entry] = Tracking.watchlist(user)
      assert entry.media_item_id == movie.id
      assert %AnotherTrackingTool.Catalog.MediaItem{} = entry.media_item
    end
  end

  describe "watch_totals" do
    test "sums film runtime for completed films only", ctx do
      %{user: user} = ctx
      film = media_item_fixture(%{kind: :movie, runtime: 136})
      planned = media_item_fixture(%{kind: :movie, runtime: 90})
      {:ok, _} = Tracking.mark_watched(user, film, %{watched_on: Date.utc_today()})
      {:ok, _} = Tracking.set_status(user, planned, :planned)

      totals = Tracking.watch_totals(user, :all)

      assert totals.films == 1
      assert totals.film_minutes == 136
      assert totals.minutes == 136
    end

    test "sums episode runtime and counts the series behind them", ctx do
      %{user: user} = ctx
      show = media_item_fixture(%{kind: :tv})
      season = season_fixture(show)
      first = episode_fixture(show, season, %{runtime: 50})
      second = episode_fixture(show, season, %{runtime: 42})

      :ok = Tracking.mark_episode(user, first)
      :ok = Tracking.mark_episode(user, second)

      totals = Tracking.watch_totals(user, :all)

      assert totals.episodes == 2
      assert totals.episode_minutes == 92
      assert totals.series == 1
    end

    test "counts a title with no runtime as zero minutes", ctx do
      %{user: user} = ctx
      film = media_item_fixture(%{kind: :movie})
      {:ok, _} = Tracking.mark_watched(user, film, %{watched_on: Date.utc_today()})

      totals = Tracking.watch_totals(user, :all)

      assert totals.films == 1
      assert totals.film_minutes == 0
    end

    test "ignores watches outside the period", ctx do
      %{user: user} = ctx
      old = media_item_fixture(%{kind: :movie, runtime: 100})
      recent = media_item_fixture(%{kind: :movie, runtime: 120})
      {:ok, _} = Tracking.mark_watched(user, old, %{watched_on: ~D[2020-02-01]})
      {:ok, _} = Tracking.mark_watched(user, recent, %{watched_on: Date.utc_today()})

      assert Tracking.watch_totals(user, :month).film_minutes == 120
      assert Tracking.watch_totals(user, :year).film_minutes == 120
      assert Tracking.watch_totals(user, :all).film_minutes == 220
    end

    test "falls back to the logging date when no watched_on is given", ctx do
      %{user: user} = ctx
      show = media_item_fixture(%{kind: :tv})
      episode = episode_fixture(show, season_fixture(show), %{runtime: 45})
      :ok = Tracking.mark_episode(user, episode)

      assert Tracking.watch_totals(user, :month).episode_minutes == 45
    end

    test "counts only the given user", ctx do
      %{user: user} = ctx
      film = media_item_fixture(%{kind: :movie, runtime: 100})
      {:ok, _} = Tracking.mark_watched(user_fixture(), film, %{watched_on: Date.utc_today()})

      assert Tracking.watch_totals(user, :all) == %{
               films: 0,
               film_minutes: 0,
               episodes: 0,
               episode_minutes: 0,
               series: 0,
               minutes: 0
             }
    end
  end

  describe "last_watched" do
    test "gives a series one row, however many episodes", ctx do
      %{user: user} = ctx
      show = media_item_fixture(%{kind: :tv, title_fr: "Severance"})
      season = season_fixture(show)
      first = episode_fixture(show, season, %{episode_number: 1, name: "Première"})
      second = episode_fixture(show, season, %{episode_number: 2, name: "Deuxième"})
      third = episode_fixture(show, season, %{episode_number: 3, name: "Troisième"})

      :ok = Tracking.mark_episode(user, first)
      :ok = Tracking.mark_episode(user, second)
      :ok = Tracking.mark_episode(user, third)

      assert [row] = Tracking.last_watched(user, :all)
      assert row.media_item.id == show.id
      assert row.episodes == 3
      assert row.latest_episode.name == "Troisième"
    end

    test "counts the latest episode by number, not by when it was logged", ctx do
      %{user: user} = ctx
      show = media_item_fixture(%{kind: :tv})
      season = season_fixture(show)
      early = episode_fixture(show, season, %{episode_number: 2, name: "Deux"})
      late = episode_fixture(show, season, %{episode_number: 7, name: "Sept"})

      :ok = Tracking.mark_episode(user, late)
      :ok = Tracking.mark_episode(user, early)

      assert [row] = Tracking.last_watched(user, :all)
      assert row.latest_episode.name == "Sept"
    end

    test "carries the overall progress for a series", ctx do
      %{user: user} = ctx
      show = media_item_fixture(%{kind: :tv})
      season = season_fixture(show)
      watched = episode_fixture(show, season, %{episode_number: 1})
      _unwatched = episode_fixture(show, season, %{episode_number: 2})

      :ok = Tracking.mark_episode(user, watched)

      assert [row] = Tracking.last_watched(user, :all)
      assert row.progress == %{watched: 1, total: 2}
    end

    test "gives a film a row with its genres loaded", ctx do
      %{user: user, movie: movie} = ctx
      {:ok, _} = Tracking.mark_watched(user, movie, %{watched_on: Date.utc_today()})

      assert [row] = Tracking.last_watched(user, :all)
      assert row.media_item.id == movie.id
      assert row.episodes == 0
      assert row.latest_episode == nil
      assert row.progress == nil
      assert is_list(row.media_item.tmdb_genres)
    end

    test "orders newest first and honours the limit", ctx do
      %{user: user, movie: old} = ctx
      recent = media_item_fixture(%{kind: :movie})
      {:ok, _} = Tracking.mark_watched(user, old, %{watched_on: ~D[2024-01-01]})
      {:ok, _} = Tracking.mark_watched(user, recent, %{watched_on: ~D[2024-06-01]})

      assert [first, second] = Tracking.last_watched(user, :all)
      assert first.media_item.id == recent.id
      assert second.media_item.id == old.id
      assert [only] = Tracking.last_watched(user, :all, 1)
      assert only.media_item.id == recent.id
    end

    test "keeps to the period and to the user", ctx do
      %{user: user, movie: movie} = ctx
      {:ok, _} = Tracking.mark_watched(user, movie, %{watched_on: ~D[2020-02-01]})
      {:ok, _} = Tracking.mark_watched(user_fixture(), movie, %{watched_on: Date.utc_today()})

      assert Tracking.last_watched(user, :month) == []
      assert [_] = Tracking.last_watched(user, :all)
    end
  end

  describe "circle_latest" do
    test "gives each person one entry, their most recent", ctx do
      %{user: me} = ctx
      marie = user_fixture()
      first = media_item_fixture(%{kind: :movie, title_fr: "Premier"})
      second = media_item_fixture(%{kind: :movie, title_fr: "Second"})

      {:ok, _} = Tracking.mark_watched(marie, first, %{watched_on: ~D[2024-01-01]})
      {:ok, _} = Tracking.mark_watched(marie, second, %{watched_on: ~D[2024-06-01]})

      assert [watch] = Tracking.circle_latest(me)
      assert watch.user.id == marie.id
      assert watch.media_item.id == second.id
    end

    test "leaves you out of your own circle", ctx do
      %{user: me, movie: movie} = ctx
      {:ok, _} = Tracking.mark_watched(me, movie, %{watched_on: Date.utc_today()})

      assert Tracking.circle_latest(me) == []
    end

    test "takes the later of a person's film and episode", ctx do
      %{user: me} = ctx
      theo = user_fixture()
      film = media_item_fixture(%{kind: :movie})
      show = media_item_fixture(%{kind: :tv})
      episode = episode_fixture(show, season_fixture(show), %{episode_number: 4})

      {:ok, _} = Tracking.mark_watched(theo, film, %{watched_on: ~D[2024-01-01]})
      :ok = Tracking.mark_episode(theo, episode, %{watched_on: ~D[2024-09-09]})

      assert [watch] = Tracking.circle_latest(me)
      assert watch.episode.id == episode.id
      assert watch.media_item.id == show.id
    end

    test "carries the rating of a film watch", ctx do
      %{user: me} = ctx
      lea = user_fixture()
      film = media_item_fixture(%{kind: :movie})
      {:ok, _} = Tracking.upsert_entry(lea, film, %{status: :completed, rating: 5})

      assert [watch] = Tracking.circle_latest(me)
      assert watch.rating == 5
      assert watch.episode == nil
    end

    test "orders people newest first and honours the limit", ctx do
      %{user: me} = ctx
      older = user_fixture()
      newer = user_fixture()
      film = media_item_fixture(%{kind: :movie})

      {:ok, _} = Tracking.mark_watched(older, film, %{watched_on: ~D[2024-01-01]})
      {:ok, _} = Tracking.mark_watched(newer, film, %{watched_on: ~D[2024-06-01]})

      assert [first, second] = Tracking.circle_latest(me)
      assert first.user.id == newer.id
      assert second.user.id == older.id
      assert [only] = Tracking.circle_latest(me, 1)
      assert only.user.id == newer.id
    end
  end
end
