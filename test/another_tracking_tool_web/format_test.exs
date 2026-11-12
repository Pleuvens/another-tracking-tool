defmodule AnotherTrackingToolWeb.FormatTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingToolWeb.Format

  describe "ago" do
    @now ~U[2026-11-12 18:00:00Z]

    test "reads in minutes within the hour" do
      assert Format.ago(~U[2026-11-12 17:45:00Z], @now) == "15 min ago"
      assert Format.ago(~U[2026-11-12 18:00:00Z], @now) == "1 min ago"
    end

    test "reads in hours within the day" do
      assert Format.ago(~U[2026-11-12 10:00:00Z], @now) == "8h ago"
    end

    test "reads in days within the week" do
      assert Format.ago(~U[2026-11-09 18:00:00Z], @now) == "3d ago"
    end

    test "reads in weeks past that" do
      assert Format.ago(~U[2026-10-22 18:00:00Z], @now) == "3w ago"
    end
  end

  describe "watch_time" do
    test "reads in minutes below an hour" do
      assert Format.watch_time(0) == %{value: "0", unit: "minutes"}
      assert Format.watch_time(1) == %{value: "1", unit: "minute"}
      assert Format.watch_time(45) == %{value: "45", unit: "minutes"}
    end

    test "reads in hours up to two days" do
      assert Format.watch_time(60) == %{value: "1", unit: "hour"}
      assert Format.watch_time(136) == %{value: "2.3", unit: "hours"}
      assert Format.watch_time(2_879) == %{value: "48", unit: "hours"}
    end

    test "reads in days up to two months" do
      assert Format.watch_time(2_880) == %{value: "2", unit: "days"}
      assert Format.watch_time(5_616) == %{value: "3.9", unit: "days"}
      assert Format.watch_time(86_400) == %{value: "60", unit: "days"}
    end

    test "reads in months past that" do
      assert Format.watch_time(87_660) == %{value: "2", unit: "months"}
      assert Format.watch_time(438_300) == %{value: "10", unit: "months"}
    end

    test "drops a trailing zero rather than showing 1.0" do
      assert Format.watch_time(120) == %{value: "2", unit: "hours"}
    end
  end
end
