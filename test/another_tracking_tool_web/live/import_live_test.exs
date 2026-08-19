defmodule AnotherTrackingToolWeb.ImportLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import Phoenix.LiveViewTest

  alias AnotherTrackingTool.AccountsFixtures
  alias AnotherTrackingTool.Imports.ImportWorker

  setup %{conn: conn} do
    %{conn: log_in_user(conn, AccountsFixtures.user_fixture())}
  end

  test "shows the integrations hub", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/import")
    assert html =~ "Yamtrack"
    assert html =~ "Letterboxd"
    assert html =~ "Coming soon"
  end

  test "uploading a Yamtrack CSV enqueues an import", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/import")

    csv = """
    media_id,source,media_type,title,image,season_number,episode_number,score,status,notes,start_date,end_date,progress
    603,tmdb,movie,The Matrix,,,,8,Completed,,,2024-01-15,
    """

    file =
      file_input(lv, "#yamtrack-form", :file, [
        %{name: "export.csv", content: csv, type: "text/csv"}
      ])

    render_upload(file, "export.csv")
    lv |> element("#yamtrack-form") |> render_submit()

    assert_enqueued(worker: ImportWorker)
  end
end
