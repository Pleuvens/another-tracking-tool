defmodule AnotherTrackingTool.TrackingTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures
  import AnotherTrackingTool.TrackingFixtures

  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingTool.Tracking.WatchEntry

  setup do
    %{user: user_fixture(), movie: media_item_fixture(%{kind: :movie})}
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
  end
end
