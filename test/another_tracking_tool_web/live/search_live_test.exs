defmodule AnotherTrackingToolWeb.SearchLiveTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AnotherTrackingTool.TmdbStub

  setup %{conn: conn} do
    %{conn: log_in_user(conn, AnotherTrackingTool.AccountsFixtures.user_fixture())}
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
end
