defmodule AnotherTrackingTool.Integrations.Connector do
  @moduledoc "Contract each integration source implements: authenticate a request and turn it into events."

  @callback source() :: atom()
  @callback verify(conn :: term(), secret :: String.t()) :: :ok | {:error, term()}
  @callback parse(raw :: term()) :: {:ok, [struct()]} | :ignore | {:error, term()}
end
