defmodule AnotherTrackingTool.MediaEnumsTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.MediaEnums

  test "cinema_kinds and kinds" do
    assert MediaEnums.cinema_kinds() == [:movie, :tv]
    assert MediaEnums.kinds() == [:movie, :tv]
  end

  test "to_existing_cinema_kind maps known strings and rejects the rest" do
    assert MediaEnums.to_existing_cinema_kind("movie") == :movie
    assert MediaEnums.to_existing_cinema_kind("tv") == :tv
    assert MediaEnums.to_existing_cinema_kind("person") == nil
    assert MediaEnums.to_existing_cinema_kind("garbage") == nil
  end
end
