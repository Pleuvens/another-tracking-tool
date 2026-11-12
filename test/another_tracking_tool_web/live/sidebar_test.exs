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
end
