defmodule AnotherTrackingToolWeb.Format do
  @moduledoc "View-layer formatting helpers (dates, times, watch verbs)."

  use Gettext, backend: AnotherTrackingToolWeb.Gettext

  def day_label(date) do
    today = Date.utc_today()

    cond do
      date == today -> gettext("Today")
      date == Date.add(today, -1) -> gettext("Yesterday")
      true -> Calendar.strftime(date, "%d/%m/%Y")
    end
  end

  def time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  def percent(_done, total) when total in [nil, 0], do: 0
  def percent(done, total), do: round(done / total * 100)

  def watch_verb(:completed), do: dgettext("feed", "finished")
  def watch_verb(:watching), do: dgettext("feed", "started")
  def watch_verb(:dropped), do: dgettext("feed", "dropped")
  def watch_verb(:planned), do: dgettext("feed", "added to their list")
end
