defmodule AnotherTrackingTool.MediaEnums do
  @moduledoc "Shared enumerations for the media domain."

  @cinema_kinds [:movie, :tv]
  @kinds @cinema_kinds

  @cinema_kind_by_string Map.new(@cinema_kinds, &{Atom.to_string(&1), &1})

  def cinema_kinds, do: @cinema_kinds
  def kinds, do: @kinds

  def to_existing_cinema_kind(string), do: Map.get(@cinema_kind_by_string, string)
end
