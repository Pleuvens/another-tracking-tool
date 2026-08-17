defmodule AnotherTrackingTool.WatchSources do
  @moduledoc "Where a watch entry came from."

  @all [:manual, :plex, :import]
  @default :manual

  def all, do: @all
  def default, do: @default
end
