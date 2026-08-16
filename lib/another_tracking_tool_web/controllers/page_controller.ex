defmodule AnotherTrackingToolWeb.PageController do
  use AnotherTrackingToolWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
