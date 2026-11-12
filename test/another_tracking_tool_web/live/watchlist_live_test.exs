defmodule AnotherTrackingToolWeb.WatchlistLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.AccountsFixtures
  alias AnotherTrackingTool.Tracking

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "lists everything you track, whatever its status", %{conn: conn, user: user} do
    planned = media_item_fixture(%{kind: :movie, title_fr: "Planned Movie"})
    watched = media_item_fixture(%{kind: :movie, title_fr: "Watched Movie"})
    {:ok, _} = Tracking.set_status(user, planned, :planned)
    {:ok, _} = Tracking.set_status(user, watched, :completed)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "Planned Movie"
    assert html =~ "Watched Movie"
  end

  test "leaves other people's titles out", %{conn: conn} do
    other = AccountsFixtures.user_fixture()
    theirs = media_item_fixture(%{kind: :movie, title_fr: "Theirs"})
    {:ok, _} = Tracking.set_status(other, theirs, :planned)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    refute html =~ "Theirs"
  end

  test "filters by status, with counts on the chips", %{conn: conn, user: user} do
    planned = media_item_fixture(%{kind: :movie, title_fr: "Planned Movie"})
    watched = media_item_fixture(%{kind: :movie, title_fr: "Watched Movie"})
    {:ok, _} = Tracking.set_status(user, planned, :planned)
    {:ok, _} = Tracking.set_status(user, watched, :completed)

    {:ok, lv, html} = live(conn, ~p"/watchlist")
    assert html =~ "All · 2"
    assert html =~ "Planned · 1"

    html = lv |> element("button", "Planned · 1") |> render_click()

    assert html =~ "Planned Movie"
    refute html =~ "Watched Movie"
  end

  test "a series tile carries its progress and season", %{conn: conn, user: user} do
    show = media_item_fixture(%{kind: :tv, title_fr: "Severance"})
    season = season_fixture(show, %{season_number: 2})
    watched = episode_fixture(show, season, %{episode_number: 1})
    _unwatched = episode_fixture(show, season, %{episode_number: 2})

    :ok = Tracking.mark_episode(user, watched)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "Severance"
    assert html =~ "1 of 2 episodes"
    assert html =~ "S2"
  end

  test "a rated film tile shows its stars", %{conn: conn, user: user} do
    movie = media_item_fixture(%{kind: :movie, title_fr: "Dune"})
    {:ok, _} = Tracking.rate(user, movie, 4)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "★"
  end

  test "an unrated film tile falls back to its status", %{conn: conn, user: user} do
    movie = media_item_fixture(%{kind: :movie, title_fr: "Dune"})
    {:ok, _} = Tracking.set_status(user, movie, :planned)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "Planned"
  end

  test "an empty filter says so", %{conn: conn, user: user} do
    movie = media_item_fixture(%{kind: :movie})
    {:ok, _} = Tracking.set_status(user, movie, :planned)

    {:ok, lv, _html} = live(conn, ~p"/watchlist")
    html = lv |> element("button", "Dropped · 0") |> render_click()

    assert html =~ "Nothing with that status"
  end

  test "shows the empty state", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist")
    assert html =~ "Nothing planned yet"
  end

  test "reloads when my planned set changes, ignores other users", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/watchlist")

    # another user's activity is ignored
    other = AccountsFixtures.user_fixture()

    {:ok, _} =
      Tracking.set_status(
        other,
        media_item_fixture(%{kind: :movie, title_fr: "Theirs"}),
        :planned
      )

    refute render(lv) =~ "Theirs"

    # my own planning shows up live
    mine = media_item_fixture(%{kind: :movie, title_fr: "Mine"})
    {:ok, _} = Tracking.set_status(user, mine, :planned)
    assert render(lv) =~ "Mine"
  end

  test "survives an episode-watched activity broadcast", %{conn: conn, user: user} do
    show = media_item_fixture(%{kind: :tv})
    season = season_fixture(show)
    episode = episode_fixture(show, season)

    {:ok, lv, _html} = live(conn, ~p"/watchlist")

    Tracking.mark_episode(user, episode)

    assert render(lv) =~ "My list"
  end
end
