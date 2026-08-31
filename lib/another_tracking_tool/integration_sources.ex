defmodule AnotherTrackingTool.IntegrationSources do
  @moduledoc "External playback sources the app can integrate with."

  @all [:plex]
  @by_string Map.new(@all, &{Atom.to_string(&1), &1})

  def all, do: @all

  def from_string(string), do: Map.get(@by_string, string)
end
