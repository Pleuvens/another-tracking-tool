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

  test "lists the user's planned titles", %{conn: conn, user: user} do
    planned = media_item_fixture(%{kind: :movie, title_fr: "Planned Movie"})
    watched = media_item_fixture(%{kind: :movie, title_fr: "Watched Movie"})
    {:ok, _} = Tracking.set_status(user, planned, :planned)
    {:ok, _} = Tracking.set_status(user, watched, :completed)

    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "Planned Movie"
    refute html =~ "Watched Movie"
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
end
