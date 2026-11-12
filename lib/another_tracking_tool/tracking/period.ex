defmodule AnotherTrackingTool.Tracking.Period do
  import Ecto.Query

  def start(:all), do: nil
  def start(:month), do: Date.beginning_of_month(Date.utc_today())
  def start(:year), do: %{Date.utc_today() | month: 1, day: 1}

  def since(query, nil), do: query

  def since(query, %Date{} = date),
    do: where(query, [w], coalesce(w.watched_on, fragment("(?)::date", w.inserted_at)) >= ^date)
end
