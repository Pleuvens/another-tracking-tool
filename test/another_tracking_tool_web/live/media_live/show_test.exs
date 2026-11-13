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

  describe "tv show" do
    setup %{user: user} do
      show = media_item_fixture(%{kind: :tv, title_fr: "Severance"})
      season = season_fixture(show, %{season_number: 1})

      episode =
        episode_fixture(show, season, %{episode_number: 1, name: "Good News About Hell"})

      %{show: show, season: season, episode: episode, user: user}
    end

    test "folds the finished seasons and opens the one in progress", ctx do
      %{conn: conn, user: user, show: show, season: season} = ctx
      second = season_fixture(show, %{season_number: 2})
      old = episode_fixture(show, season, %{episode_number: 2, name: "Half Loop"})
      current = episode_fixture(show, second, %{episode_number: 1, name: "Hello, Ms. Cobel"})
      episode_fixture(show, second, %{episode_number: 2, name: "Goodbye, Mrs. Selvig"})

      :ok = Tracking.mark_episode(user, current)

      {:ok, _lv, html} = live(conn, ~p"/media/#{show.id}")

      assert html =~ "Hello, Ms. Cobel"
      refute html =~ "Half Loop"
      refute html =~ old.name
    end

    test "a season unfolds on click", ctx do
      %{conn: conn, show: show, season: season} = ctx
      season_fixture(show, %{season_number: 2})
      episode_fixture(show, season, %{episode_number: 2, name: "Half Loop"})

      {:ok, lv, _html} = live(conn, ~p"/media/#{show.id}")

      html =
        lv |> element("button[phx-click='toggle_season'][phx-value-season='1']") |> render_click()

      assert html =~ "Half Loop"
    end

    test "a finished season offers to clear itself", ctx do
      %{conn: conn, user: user, show: show, episode: episode} = ctx

      :ok = Tracking.mark_episode(user, episode)

      {:ok, lv, html} = live(conn, ~p"/media/#{show.id}")
      assert html =~ "Clear season"

      lv |> element("button[phx-click='unmark_season']") |> render_click()

      assert Tracking.watched_episode_ids(user, show) |> MapSet.size() == 0
      assert render(lv) =~ "Mark season watched"
    end

    test "lists episodes; toggling marks watched and updates progress", ctx do
      %{conn: conn, user: user, show: show, episode: episode} = ctx
      {:ok, lv, html} = live(conn, ~p"/media/#{show.id}")
      assert html =~ "Good News About Hell"
      assert html =~ "0/1"

      lv |> element("button[phx-value-id='#{episode.id}']") |> render_click()

      assert render(lv) =~ "1/1"
      assert MapSet.member?(Tracking.watched_episode_ids(user, show), episode.id)
      assert Tracking.get_entry(user, show).status == :completed
    end
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

  test "the tracking panel marks the chosen status", %{conn: conn, user: user, movie: movie} do
    {:ok, _} = Tracking.set_status(user, movie, :completed)
    {:ok, lv, _html} = live(conn, ~p"/media/#{movie.id}")

    assert lv |> element("button[aria-pressed='true']") |> render() =~ "Completed"
  end

  test "the watched date opens an editor in place", %{conn: conn, movie: movie} do
    {:ok, lv, html} = live(conn, ~p"/media/#{movie.id}")
    refute html =~ ~s(type="date")

    html = lv |> element("button[phx-click='edit_date']") |> render_click()

    assert html =~ ~s(type="date")
  end

  test "not for me is one of the status choices", %{conn: conn, user: user, movie: movie} do
    {:ok, lv, html} = live(conn, ~p"/media/#{movie.id}")
    assert html =~ "Not for me"

    lv |> element("button", "Not for me") |> render_click()

    assert Tracking.get_entry(user, movie).status == :not_interested
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

  describe "the side column" do
    test "lists who rated what rather than an average alone", ctx do
      %{conn: conn, user: user, movie: movie} = ctx
      marie = AnotherTrackingTool.AccountsFixtures.user_fixture(email: "marie@example.com")
      theo = AnotherTrackingTool.AccountsFixtures.user_fixture(email: "theo@example.com")

      {:ok, _} = Tracking.upsert_entry(marie, movie, %{status: :completed, rating: 5})
      {:ok, _} = Tracking.set_status(theo, movie, :watching)
      {:ok, _} = Tracking.rate(user, movie, 4)

      {:ok, _lv, html} = live(conn, ~p"/media/#{movie.id}")

      assert html =~ "marie"
      assert html =~ "theo"
      assert html =~ "Watching"
      assert html =~ "4.5"
    end

    test "says when the circle is empty", %{conn: conn, movie: movie} do
      {:ok, _lv, html} = live(conn, ~p"/media/#{movie.id}")

      assert html =~ "No one yet"
      assert html =~ "No one has said anything yet"
    end

    test "a comment shows its author by name", %{conn: conn, user: user, movie: movie} do
      {:ok, _} = Tracking.create_comment(user, movie, "Seen it twice.")

      {:ok, _lv, html} = live(conn, ~p"/media/#{movie.id}")

      assert html =~ "Seen it twice."
      refute html =~ user.email
    end

    test "the circle and the comments sit beside the detail", %{conn: conn, movie: movie} do
      {:ok, _lv, html} = live(conn, ~p"/media/#{movie.id}")

      assert html =~ "lg:grid-cols-[1fr_280px]"
      assert html =~ "<aside"
    end
  end
end
