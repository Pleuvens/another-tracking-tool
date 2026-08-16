defmodule AnotherTrackingTool.CoerceTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.Coerce

  describe "presence/1" do
    test "nil and empty string become nil" do
      assert Coerce.presence(nil) == nil
      assert Coerce.presence("") == nil
    end

    test "other values pass through" do
      assert Coerce.presence("x") == "x"
      assert Coerce.presence(0) == 0
    end
  end

  describe "date/1" do
    test "parses ISO dates" do
      assert Coerce.date("2024-03-01") == ~D[2024-03-01]
    end

    test "nil, empty, and unparseable values become nil" do
      assert Coerce.date(nil) == nil
      assert Coerce.date("") == nil
      assert Coerce.date("nope") == nil
    end
  end
end
