defmodule AnotherTrackingToolWeb.PageControllerTest do
  use AnotherTrackingToolWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "let the posters do the talking"
  end
end
