defmodule AnotherTrackingToolWeb.MediaLive.ShowTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Tracking

  setup %{conn: conn} do
    user = AnotherTrackingTool.AccountsFixtures.user_fixture()
    movie = media_item_fixture(%{kind: :movie, title_fr: "Dune"})
    %{conn: log_in_user(conn, user), user: user, movie: movie}
  end

  test "renders the movie", %{conn: conn, movie: movie} do
    {:ok, _lv, html} = live(conn, ~p"/media/#{movie.id}")
    assert html =~ "Dune"
  end

  test "setting a status persists and highlights it", %{conn: conn, user: user, movie: movie} do
    {:ok, lv, _html} = live(conn, ~p"/media/#{movie.id}")

    lv |> element("button", "Watching") |> render_click()

    assert Tracking.get_entry(user, movie).status == :watching
  end

  test "rating a movie persists it", %{conn: conn, user: user, movie: movie} do
    {:ok, lv, _html} = live(conn, ~p"/media/#{movie.id}")

    lv |> element("button[phx-value-rating='4']") |> render_click()

    assert Tracking.get_entry(user, movie).rating == 4
  end

  test "posting a comment adds it and clears the input", %{conn: conn, movie: movie} do
    {:ok, lv, _html} = live(conn, ~p"/media/#{movie.id}")

    lv |> form("form[phx-submit=comment]", comment: %{body: "Loved it"}) |> render_change()
    html = lv |> form("form[phx-submit=comment]", comment: %{body: "Loved it"}) |> render_submit()

    assert html =~ "Loved it"
    refute html =~ ~s(value="Loved it")
  end

  test "a broadcast from another session updates the page", %{conn: conn, movie: movie} do
    {:ok, lv, _html} = live(conn, ~p"/media/#{movie.id}")

    other = AnotherTrackingTool.AccountsFixtures.user_fixture()
    {:ok, _} = Tracking.create_comment(other, movie, "From afar")

    assert render(lv) =~ "From afar"
  end
end
