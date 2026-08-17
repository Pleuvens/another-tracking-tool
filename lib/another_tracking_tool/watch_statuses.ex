defmodule AnotherTrackingTool.WatchStatuses do
  @moduledoc "Per-user watch statuses for a title."

  @all [:watching, :completed, :dropped, :planned]

  def all, do: @all
end
