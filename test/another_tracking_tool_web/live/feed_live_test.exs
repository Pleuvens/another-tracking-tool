defmodule AnotherTrackingToolWeb.FeedLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures
  import AnotherTrackingTool.TrackingFixtures

  alias AnotherTrackingTool.AccountsFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, AccountsFixtures.user_fixture())}
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

  test "new activity from another session appears live", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/feed")

    other = AccountsFixtures.user_fixture(email: "julien@example.com")
    movie = media_item_fixture(%{kind: :movie, title_fr: "Arrival"})
    watch_entry_fixture(other, movie, %{status: :watching})

    html = render(lv)
    assert html =~ "julien@example.com"
    assert html =~ "Arrival"
  end
end
