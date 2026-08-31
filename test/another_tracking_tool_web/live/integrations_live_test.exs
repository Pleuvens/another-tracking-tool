defmodule AnotherTrackingToolWeb.IntegrationsLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Integrations

  describe "access" do
    test "redirects a non-admin to the feed", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} =
               conn |> log_in_user(user_fixture()) |> live(~p"/integrations")

      assert path == ~p"/feed"
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      %{conn: log_in_user(conn, admin_user_fixture())}
    end

    test "shows the webhook URL and the empty accounts state", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/integrations")

      assert html =~ "Webhook URL"
      assert html =~ "/integrations/plex/webhook/"
      assert html =~ "No Plex accounts yet"
    end

    test "lists a discovered account and assigns it to a user", %{conn: conn} do
      user = user_fixture()
      {:ok, _account} = Integrations.record_account(:plex, "42", "Alice")

      {:ok, lv, html} = live(conn, ~p"/integrations")
      assert html =~ "Alice"

      lv |> form("form", %{"user_id" => user.id}) |> render_change()

      assert Integrations.mapped_user_id(:plex, "42") == user.id
    end
  end
end
