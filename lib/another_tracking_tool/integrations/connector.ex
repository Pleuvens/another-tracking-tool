defmodule AnotherTrackingTool.Integrations.Connector do
  @moduledoc "Contract each integration source implements: turn a raw request into normalized events."

  @callback source() :: atom()
  @callback parse(raw :: term()) :: {:ok, [struct()]} | :ignore | {:error, term()}
end
