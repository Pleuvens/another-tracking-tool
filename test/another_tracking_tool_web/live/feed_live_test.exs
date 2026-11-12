defmodule AnotherTrackingToolWeb.FeedLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Tracking

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "shows a title you watched", %{conn: conn, user: user} do
    movie = media_item_fixture(%{kind: :movie, title_fr: "Dune"})
    {:ok, _} = Tracking.mark_watched(user, movie, %{watched_on: Date.utc_today()})

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "Last watched"
    assert html =~ "Dune"
    assert html =~ "Today"
  end

  test "empty state when you have watched nothing", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/feed")
    assert html =~ "Nothing here yet"
  end

  test "someone else's watch lands in the circle, not in your rows", %{conn: conn} do
    other = AccountsFixtures.user_fixture(email: "julien@example.com")
    movie = media_item_fixture(%{kind: :movie, title_fr: "Arrival"})
    {:ok, _} = Tracking.mark_watched(other, movie, %{watched_on: Date.utc_today()})

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "Your circle"
    assert html =~ "julien"
    assert html =~ "Arrival"
    assert html =~ "Nothing here yet"
  end

  test "the circle shows each person once", %{conn: conn} do
    marie = AccountsFixtures.user_fixture(email: "marie@example.com")
    first = media_item_fixture(%{kind: :movie, title_fr: "Premier"})
    second = media_item_fixture(%{kind: :movie, title_fr: "Second"})

    {:ok, _} = Tracking.mark_watched(marie, first, %{watched_on: ~D[2024-01-01]})
    {:ok, _} = Tracking.mark_watched(marie, second, %{watched_on: Date.utc_today()})

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "Second"
    refute html =~ "Premier"
  end

  test "no circle section when nobody else has watched anything", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/feed")
    refute html =~ "Your circle"
  end

  test "a series takes one row, whatever the episode count", %{conn: conn, user: user} do
    show = media_item_fixture(%{kind: :tv, title_fr: "Severance"})
    season = season_fixture(show)
    first = episode_fixture(show, season, %{episode_number: 1, name: "Première"})
    second = episode_fixture(show, season, %{episode_number: 2, name: "Deuxième"})

    :ok = Tracking.mark_episode(user, first)
    :ok = Tracking.mark_episode(user, second)

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ "Severance"
    assert html =~ "up to 1×2"
    assert html =~ "Deuxième"
    assert html =~ "2 ep"
    refute html =~ "Première"
  end

  test "your own watch from another session appears live", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/feed")

    movie = media_item_fixture(%{kind: :movie, title_fr: "Arrival"})
    {:ok, _} = Tracking.mark_watched(user, movie, %{watched_on: Date.utc_today()})

    assert render(lv) =~ "Arrival"
  end

  test "someone else's watch reaches the circle live", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/feed")

    other = AccountsFixtures.user_fixture()
    movie = media_item_fixture(%{kind: :movie, title_fr: "Stalker"})
    {:ok, _} = Tracking.mark_watched(other, movie, %{watched_on: Date.utc_today()})

    html = render(lv)
    assert html =~ "Your circle"
    assert html =~ "Stalker"
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
