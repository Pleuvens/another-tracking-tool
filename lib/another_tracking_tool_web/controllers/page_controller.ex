defmodule AnotherTrackingToolWeb.PageController do
  use AnotherTrackingToolWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/feed")
    else
      render(conn, :home)
    end
  end
end
