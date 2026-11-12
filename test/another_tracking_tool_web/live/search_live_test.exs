defmodule AnotherTrackingToolWeb.SearchLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.{TmdbStub, Tracking}
  alias AnotherTrackingTool.AccountsFixtures

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp film(title, attrs \\ %{}) do
    media_item_fixture(Map.merge(%{kind: :movie, title_fr: title, runtime: 100}, attrs))
  end

  test "searching lists movie and tv results, dropping people", %{conn: conn} do
    TmdbStub.stub([
      {"/3/search/multi",
       %{
         "results" => [
           %{"media_type" => "movie", "id" => 603, "title" => "Matrix"},
           %{"media_type" => "tv", "id" => 95396, "name" => "Severance"},
           %{"media_type" => "person", "id" => 1, "name" => "Keanu"}
         ]
       }}
    ])

    {:ok, lv, _html} = live(conn, ~p"/search")

    html = lv |> form("form", %{"q" => "matrix"}) |> render_change()

    assert html =~ "Matrix"
    assert html =~ "Severance"
    refute html =~ "Keanu"
  end

  describe "the deck" do
    test "opens with one suggestion and why it is there", %{conn: conn, user: user} do
      drama = genre_fixture(%{name_fr: "Drame"})
      seen = film("Seen", %{runtime: 300}) |> with_genres([drama])
      {:ok, _} = Tracking.mark_watched(user, seen, %{watched_on: Date.utc_today()})

      film("Suggested") |> with_genres([drama])

      {:ok, _lv, html} = live(conn, ~p"/search")

      assert html =~ "Suggested"
      assert html =~ "Your most-watched genre: Drame"
      assert html =~ "Not for me"
    end

    test "a decision records the status and offers an undo", %{conn: conn, user: user} do
      movie = film("Decided")

      {:ok, lv, _html} = live(conn, ~p"/search")

      html =
        lv
        |> element(~s(button[phx-value-status="planned"][phx-value-id="#{movie.id}"]))
        |> render_click()

      assert Tracking.get_entry(user, movie).status == :planned
      assert html =~ "Undo"
      assert html =~ "Decided"
    end

    test "undo puts the title back in the deck", %{conn: conn, user: user} do
      movie = film("Reverted")

      {:ok, lv, _html} = live(conn, ~p"/search")

      lv
      |> element(~s(button[phx-value-status="not_interested"][phx-value-id="#{movie.id}"]))
      |> render_click()

      assert Tracking.get_entry(user, movie).status == :not_interested

      html = lv |> element(~s(button[phx-click="undo"])) |> render_click()

      assert Tracking.get_entry(user, movie) == nil
      assert html =~ "Reverted"
      refute html =~ "Undo"
    end

    test "marking watched offers the stars straight away", %{conn: conn, user: user} do
      movie = film("Rated")

      {:ok, lv, _html} = live(conn, ~p"/search")

      lv
      |> element(~s(button[phx-value-status="completed"][phx-value-id="#{movie.id}"]))
      |> render_click()

      lv |> element(~s(button[phx-value-rating="4"])) |> render_click()

      assert Tracking.get_entry(user, movie).rating == 4
    end

    test "an arrow key decides the top card", %{conn: conn, user: user} do
      movie = film("Keyed")

      {:ok, lv, _html} = live(conn, ~p"/search")

      lv |> element("#deck") |> render_keydown(%{"key" => "ArrowRight"})

      assert Tracking.get_entry(user, movie).status == :planned
    end

    test "the card shows the title and its details below the art", %{conn: conn} do
      drama = genre_fixture(%{name_fr: "Drame"})

      film("Perfect Days", %{
        runtime: 124,
        overview_fr: "Hirayama nettoie des toilettes publiques à Tokyo."
      })
      |> with_genres([drama])

      {:ok, _lv, html} = live(conn, ~p"/search")

      assert html =~ "Perfect Days"
      assert html =~ "124 min"
      assert html =~ "Drame"
      assert html =~ "Hirayama nettoie"
      assert html =~ "Open page"

      # the art is a shrinkable row, so the body below it is never clipped away
      assert html =~ "min-h-0"
    end

    test "a series card counts its episodes", %{conn: conn} do
      show = media_item_fixture(%{kind: :tv, title_fr: "Severance"})
      season = season_fixture(show)
      episode_fixture(show, season, %{episode_number: 1})
      episode_fixture(show, season, %{episode_number: 2})

      {:ok, _lv, html} = live(conn, ~p"/search")

      assert html =~ "Severance"
      assert html =~ "2 episodes"
      assert html =~ "Series"
    end

    test "says so when there is nothing left to suggest", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/search")

      assert html =~ "That is every suggestion"
    end

    test "a search replaces the deck and clearing it brings the deck back", %{conn: conn} do
      film("In the deck")

      TmdbStub.stub([
        {"/3/search/multi",
         %{"results" => [%{"media_type" => "movie", "id" => 603, "title" => "Matrix"}]}}
      ])

      {:ok, lv, html} = live(conn, ~p"/search")
      assert html =~ "In the deck"

      html = lv |> form("form", %{"q" => "matrix"}) |> render_change()
      assert html =~ "Matrix"
      refute html =~ "Use the buttons or the arrow keys"

      html = lv |> form("form", %{"q" => ""}) |> render_change()
      assert html =~ "In the deck"
      assert html =~ "Use the buttons or the arrow keys"
    end
  end
end
