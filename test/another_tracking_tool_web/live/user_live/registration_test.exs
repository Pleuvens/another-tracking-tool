defmodule AnotherTrackingToolWeb.UserLive.RegistrationTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Accounts

  describe "Registration page" do
    test "renders the bootstrap form on an empty instance", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create the first account"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Create the first account"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               ~r/An email was sent to .*, please access it to confirm your account/
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "admin bootstrap" do
    test "first registration on an empty instance creates an admin", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, _lv, _html} = render_submit(form) |> follow_redirect(conn, ~p"/users/log-in")

      assert Accounts.get_user_by_email(email).admin
    end
  end

  describe "invite-gated registration" do
    test "bare registration is closed once the instance has users", %{conn: conn} do
      user_fixture()

      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "You need an invitation to join"
      refute html =~ "Create an account"
    end

    test "a valid invite renders the form and creates a non-admin user", %{conn: conn} do
      invite = invite_fixture()

      {:ok, lv, html} = live(conn, ~p"/users/register/#{invite.code}")
      assert html =~ "been invited"

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, _lv, _html} = render_submit(form) |> follow_redirect(conn, ~p"/users/log-in")

      refute Accounts.get_user_by_email(email).admin
      refute Accounts.get_redeemable_invite(invite.code)
    end

    test "an expired invite is treated as no invite", %{conn: conn} do
      invite = invite_fixture() |> expire_invite()

      {:ok, _lv, html} = live(conn, ~p"/users/register/#{invite.code}")

      assert html =~ "You need an invitation to join"
      refute html =~ "Create an account"
    end

    test "a used invite is treated as no invite", %{conn: conn} do
      invite = invite_fixture()
      {:ok, _user} = Accounts.register_user_with_invite(invite.code, valid_user_attributes())

      {:ok, _lv, html} = live(conn, ~p"/users/register/#{invite.code}")

      assert html =~ "You need an invitation to join"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
