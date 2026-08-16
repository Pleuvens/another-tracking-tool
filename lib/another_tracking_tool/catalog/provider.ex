defmodule AnotherTrackingTool.Catalog.Provider do
  @moduledoc "Contract a catalog metadata provider (TMDB, later others) must implement."

  @callback source() :: atom()
  @callback search(query :: String.t(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback enrich(media_item :: struct()) :: {:ok, struct()} | {:error, term()}
end
