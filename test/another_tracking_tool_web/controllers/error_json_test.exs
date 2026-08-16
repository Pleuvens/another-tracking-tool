defmodule AnotherTrackingToolWeb.ErrorJSONTest do
  use AnotherTrackingToolWeb.ConnCase, async: true

  test "renders 404" do
    assert AnotherTrackingToolWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert AnotherTrackingToolWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
