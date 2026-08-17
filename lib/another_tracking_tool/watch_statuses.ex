defmodule AnotherTrackingTool.WatchStatuses do
  @moduledoc "Per-user watch statuses for a title."

  @all [:watching, :completed, :dropped, :planned]
  @by_string Map.new(@all, &{Atom.to_string(&1), &1})

  def all, do: @all

  def from_string(string), do: Map.get(@by_string, string)
end
