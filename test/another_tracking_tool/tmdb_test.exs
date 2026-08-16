defmodule AnotherTrackingTool.TmdbTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.Tmdb
  alias AnotherTrackingTool.TmdbStub

  test "search_multi decodes the body on 200" do
    TmdbStub.stub([{"/3/search/multi", %{"results" => [%{"id" => 1}]}}])
    assert {:ok, %{"results" => [%{"id" => 1}]}} = Tmdb.search_multi("dune")
  end

  test "a non-200 response becomes an http error" do
    TmdbStub.stub([])
    assert {:error, {:http, 404, _}} = Tmdb.details(:movie, 999)
  end
end
