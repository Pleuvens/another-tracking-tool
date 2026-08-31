defmodule AnotherTrackingToolWeb.InviteLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Accounts

  describe "access" do
    test "redirects a guest to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/invites")
      assert path == ~p"/users/log-in"
    end

    test "redirects a non-admin to the feed", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} =
               conn |> log_in_user(user_fixture()) |> live(~p"/invites")

      assert path == ~p"/feed"
    end
  end

  describe "admin invite management" do
    setup %{conn: conn} do
      admin = admin_user_fixture()
      %{conn: log_in_user(conn, admin), admin: admin}
    end

    test "renders the empty invites page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/invites")

      assert html =~ "Invites"
      assert html =~ "Create invite link"
      assert html =~ "No invites yet"
    end

    test "creates an invite with a shareable link", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/invites")

      html = lv |> element("button", "Create invite link") |> render_click()

      assert html =~ "/users/register/"
      assert html =~ "Pending"
      refute html =~ "No invites yet"
    end

    test "shows used and expired invites", %{conn: conn, admin: admin} do
      used = invite_fixture(admin)
      {:ok, _user} = Accounts.register_user_with_invite(used.code, valid_user_attributes())
      invite_fixture(admin) |> expire_invite()

      {:ok, _lv, html} = live(conn, ~p"/invites")

      assert html =~ "Used"
      assert html =~ "Expired"
    end
  end
end
