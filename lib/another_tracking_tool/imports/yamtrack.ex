defmodule AnotherTrackingTool.Imports.Yamtrack do
  @moduledoc "Yamtrack CSV export."

  @behaviour AnotherTrackingTool.Imports.Source

  alias AnotherTrackingTool.Coerce

  NimbleCSV.define(__MODULE__.Parser, separator: ",", escape: "\"")

  @statuses %{
    "Completed" => :completed,
    "In progress" => :watching,
    "Planning" => :planned,
    "Paused" => :watching,
    "Dropped" => :dropped
  }

  @impl true
  def slug, do: :yamtrack

  @impl true
  def name, do: "Yamtrack"

  @impl true
  def parse(binary) do
    case __MODULE__.Parser.parse_string(binary, skip_headers: false) do
      [headers | rows] ->
        keys = Enum.map(headers, &String.trim/1)
        {:ok, rows |> Enum.map(&parse_row(keys, &1)) |> Enum.reject(&is_nil/1)}

      [] ->
        {:ok, []}
    end
  rescue
    _ -> {:error, :invalid_csv}
  end

  defp parse_row(keys, values) do
    row = keys |> Enum.zip(values) |> Map.new()

    with "tmdb" <- row["source"],
         "movie" <- row["media_type"],
         {tmdb_id, ""} <- Integer.parse(row["media_id"] || "") |> normalize(),
         status when not is_nil(status) <- @statuses[row["status"]] do
      %{
        tmdb_id: tmdb_id,
        kind: :movie,
        status: status,
        rating: rating(row["score"]),
        watched_on: date(row["end_date"]) || date(row["start_date"]),
        title: Coerce.presence(row["title"])
      }
    else
      _ -> nil
    end
  end

  defp normalize(:error), do: {nil, nil}
  defp normalize({int, rest}), do: {int, rest}

  defp rating(score) do
    case Float.parse(score || "") do
      {value, _} when value > 0 -> value |> Kernel./(2) |> round() |> min(5) |> max(0)
      _ -> nil
    end
  end

  defp date(value) do
    case Coerce.presence(value) do
      nil -> nil
      str -> str |> String.slice(0, 10) |> Coerce.date()
    end
  end
end
