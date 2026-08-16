defmodule AnotherTrackingTool.Coerce do
  @moduledoc "Coerce loose external values into domain types."

  def presence(value) when value in [nil, ""], do: nil
  def presence(value), do: value

  def date(value) when value in [nil, ""], do: nil

  def date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
