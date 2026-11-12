defmodule AnotherTrackingTool.WatchStatuses do
  @all [:watching, :completed, :dropped, :planned, :not_interested]
  @by_string Map.new(@all, &{Atom.to_string(&1), &1})

  def all, do: @all

  def from_string(string), do: Map.get(@by_string, string)
end
