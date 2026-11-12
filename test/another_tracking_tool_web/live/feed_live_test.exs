defmodule AnotherTrackingToolWeb.FeedLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures
  import AnotherTrackingTool.TrackingFixtures

  alias AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Tracking

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "shows recent activity with author and title", %{conn: conn} do
    author = AccountsFixtures.user_fixture(email: "marie@example.com")
    movie = media_item_fixture(%{kind: :movie, title_fr: "Dune"})
    watch_entry_fixture(author, movie, %{status: :completed, rating: 4})

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "marie@example.com"
    assert html =~ "Dune"
  end

  test "empty state when there is no activity", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/feed")
    assert html =~ "Nothing here yet"
  end

  test "groups an entry under its watched date", %{conn: conn} do
    author = AccountsFixtures.user_fixture()
    movie = media_item_fixture(%{kind: :movie, title_fr: "Old Movie"})

    {:ok, _} =
      AnotherTrackingTool.Tracking.mark_watched(author, movie, %{watched_on: ~D[2020-05-05]})

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "05/05/2020"
    assert html =~ "Old Movie"
  end

  test "new activity from another session appears live", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/feed")

    other = AccountsFixtures.user_fixture(email: "julien@example.com")
    movie = media_item_fixture(%{kind: :movie, title_fr: "Arrival"})
    watch_entry_fixture(other, movie, %{status: :watching})

    html = render(lv)
    assert html =~ "julien@example.com"
    assert html =~ "Arrival"
  end

  describe "totals" do
    test "shows the time watched for the current month", %{conn: conn, user: user} do
      film = media_item_fixture(%{kind: :movie, runtime: 136})
      {:ok, _} = Tracking.mark_watched(user, film, %{watched_on: Date.utc_today()})

      {:ok, _lv, html} = live(conn, ~p"/feed")

      assert html =~ "Time watched"
      assert html =~ "2.3"
      assert html =~ "hours"
    end

    test "counts films and series apart", %{conn: conn, user: user} do
      film = media_item_fixture(%{kind: :movie, runtime: 100})
      show = media_item_fixture(%{kind: :tv})
      episode = episode_fixture(show, season_fixture(show), %{runtime: 50})

      {:ok, _} = Tracking.mark_watched(user, film, %{watched_on: Date.utc_today()})
      :ok = Tracking.mark_episode(user, episode)

      {:ok, _lv, html} = live(conn, ~p"/feed")

      assert html =~ "1 episode"
      assert html =~ "2.5"
    end

    test "switching the period brings older watches in", %{conn: conn, user: user} do
      old = media_item_fixture(%{kind: :movie, runtime: 120})
      {:ok, _} = Tracking.mark_watched(user, old, %{watched_on: ~D[2020-02-01]})

      {:ok, lv, html} = live(conn, ~p"/feed")
      refute html =~ "hours"

      html = lv |> element("button", "All time") |> render_click()

      assert html =~ "2"
      assert html =~ "hours"
    end

    test "only the signed-in user's watches count", %{conn: conn} do
      other = AccountsFixtures.user_fixture()
      film = media_item_fixture(%{kind: :movie, runtime: 120})
      {:ok, _} = Tracking.mark_watched(other, film, %{watched_on: Date.utc_today()})

      {:ok, _lv, html} = live(conn, ~p"/feed")

      refute html =~ "hours"
      assert html =~ "minutes"
    end
  end
end
