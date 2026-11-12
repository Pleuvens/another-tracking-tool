defmodule AnotherTrackingToolWeb.Format do
  use Gettext, backend: AnotherTrackingToolWeb.Gettext

  def day_label(date) do
    today = Date.utc_today()

    cond do
      date == today -> dgettext("feed", "Today")
      date == Date.add(today, -1) -> dgettext("feed", "Yesterday")
      true -> Calendar.strftime(date, "%d/%m/%Y")
    end
  end

  def time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  def percent(_done, total) when total in [nil, 0], do: 0
  def percent(done, total), do: round(done / total * 100)

  @minutes_per_hour 60
  @minutes_per_day 1_440
  @minutes_per_month 43_830
  @two_days 2_880
  @two_months 87_660

  def watch_time(minutes) when minutes < @minutes_per_hour, do: scale(minutes * 1.0, :minute)
  def watch_time(minutes) when minutes < @two_days, do: scale(minutes / @minutes_per_hour, :hour)
  def watch_time(minutes) when minutes < @two_months, do: scale(minutes / @minutes_per_day, :day)
  def watch_time(minutes), do: scale(minutes / @minutes_per_month, :month)

  def watch_time_text(minutes) do
    time = watch_time(minutes)
    "#{time.value} #{time.unit}"
  end

  defp scale(value, unit) do
    figure = figure(value)
    %{value: figure, unit: unit_label(unit, plural_count(figure))}
  end

  defp figure(value) when value < 10, do: value |> Float.round(1) |> trim_zero()
  defp figure(value), do: value |> round() |> Integer.to_string()

  defp trim_zero(value) when value == trunc(value), do: Integer.to_string(trunc(value))
  defp trim_zero(value), do: :erlang.float_to_binary(value, decimals: 1)

  defp plural_count("1"), do: 1
  defp plural_count(_figure), do: 2

  defp unit_label(:minute, count), do: dngettext("feed", "minute", "minutes", count)
  defp unit_label(:hour, count), do: dngettext("feed", "hour", "hours", count)
  defp unit_label(:day, count), do: dngettext("feed", "day", "days", count)
  defp unit_label(:month, count), do: dngettext("feed", "month", "months", count)
end
