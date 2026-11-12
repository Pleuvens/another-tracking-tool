defmodule AnotherTrackingToolWeb.SidebarTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.{Accounts, AccountsFixtures, Tracking}

  test "groups the nav and marks the page you are on", %{conn: conn} do
    conn = log_in_user(conn, AccountsFixtures.user_fixture())

    {:ok, lv, html} = live(conn, ~p"/feed")

    assert html =~ "Watch"
    assert html =~ "You"
    assert html =~ "Activity"
    assert html =~ "My list"

    assert lv |> element(~s(a[aria-current="page"])) |> render() =~ "Activity"
  end

  test "counts your list beside it", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _} = Tracking.set_status(user, media_item_fixture(%{kind: :movie}), :planned)
    {:ok, _} = Tracking.set_status(user, media_item_fixture(%{kind: :movie}), :completed)

    {:ok, lv, _html} = live(conn, ~p"/feed")

    assert lv |> element(~s(a[href="/watchlist"])) |> render() =~ "2"
  end

  test "keeps the admin group to admins", %{conn: conn} do
    {:ok, _lv, html} = live(log_in_user(conn, AccountsFixtures.user_fixture()), ~p"/feed")

    refute html =~ "Admin"
    refute html =~ "Integrations"
  end

  test "shows admins their group with the pending invite count", %{conn: conn} do
    admin = AccountsFixtures.admin_user_fixture()
    {:ok, _} = Accounts.create_invite(admin)

    {:ok, lv, html} = live(log_in_user(conn, admin), ~p"/feed")

    assert html =~ "Admin"
    assert lv |> element(~s(a[href="/invites"])) |> render() =~ "1"
  end

  test "puts you and log out in one block", %{conn: conn} do
    user = AccountsFixtures.user_fixture(email: "fervil@example.com")

    {:ok, _lv, html} = live(log_in_user(conn, user), ~p"/feed")

    assert html =~ "fervil"
    assert html =~ "Log out"
  end

  test "offers search from every page, with its shortcut", %{conn: conn} do
    conn = log_in_user(conn, AccountsFixtures.user_fixture())

    for path <- [~p"/feed", ~p"/watchlist"] do
      {:ok, lv, html} = live(conn, path)

      assert html =~ "Search films and series"
      assert html =~ "⌘K"
      assert lv |> element(~s(a#search-hotkey)) |> has_element?()
    end
  end

  test "the shortcut link is bound to a hook", %{conn: conn} do
    conn = log_in_user(conn, AccountsFixtures.user_fixture())

    {:ok, _lv, html} = live(conn, ~p"/feed")

    assert html =~ ~s(phx-hook="AnotherTrackingToolWeb.Layouts.SearchHotkey")
    assert html =~ ~s(href="/search")
  end

  test "Discover does not offer a link to itself", %{conn: conn} do
    conn = log_in_user(conn, AccountsFixtures.user_fixture())

    {:ok, _lv, html} = live(conn, ~p"/search")

    assert html =~ "Discover"
    refute html =~ "Search films and series<"
  end
end
