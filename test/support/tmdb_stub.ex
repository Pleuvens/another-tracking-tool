defmodule AnotherTrackingTool.TmdbStub do
  @moduledoc """
  Routes `Req.Test` requests to canned TMDB payloads.

  Pass a list of `{path, payload}` or `{{path, language}, payload}` routes; the first
  match on request path (and language, when given) is returned as JSON. Unmatched
  requests get a 404.
  """

  def stub(routes) do
    Req.Test.stub(AnotherTrackingTool.Tmdb, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      language = conn.query_params["language"]

      matched =
        Enum.find_value(routes, fn
          {{path, lang}, payload} -> (conn.request_path == path and lang == language) && payload
          {path, payload} -> conn.request_path == path && payload
        end)

      case matched do
        nil -> conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{})
        payload -> Req.Test.json(conn, payload)
      end
    end)
  end
end
