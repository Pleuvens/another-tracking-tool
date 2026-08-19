defmodule AnotherTrackingTool.Imports.Source do
  @moduledoc "Contract for an import source."

  @callback slug() :: atom()
  @callback name() :: String.t()
  @callback parse(binary()) :: {:ok, [map()]} | {:error, term()}
end
