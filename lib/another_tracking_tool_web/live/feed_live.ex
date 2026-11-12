defmodule AnotherTrackingToolWeb.FeedLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingToolWeb.{Avatars, Format}

  @periods [:month, :year, :all]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tracking.subscribe_activity()

    {:ok, socket |> assign(:periods, @periods) |> assign(:period, :month) |> load()}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply, socket |> assign(:period, period_from(period)) |> load()}
  end

  @impl true
  def handle_info({:activity, _activity}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    totals = Tracking.watch_totals(me(socket), socket.assigns.period)

    socket
    |> assign(:activity, Tracking.recent_activity())
    |> assign(:totals, totals)
    |> assign(:watched, Format.watch_time(totals.minutes))
  end

  defp me(socket), do: socket.assigns.current_scope.user

  defp period_from(period), do: Enum.find(@periods, :month, &(Atom.to_string(&1) == period))

  defp period_label(:month), do: dgettext("feed", "This month")
  defp period_label(:year), do: dgettext("feed", "This year")
  defp period_label(:all), do: dgettext("feed", "All time")

  defp period_note(:month), do: dgettext("feed", "so far this month")
  defp period_note(:year), do: dgettext("feed", "so far this year")
  defp period_note(:all), do: dgettext("feed", "everything you have logged")

  defp groups(activity) do
    activity
    |> Enum.group_by(&DateTime.to_date(&1.at))
    |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})
  end

  defp verb(%{type: :movie, status: status}), do: Format.watch_verb(status)
  defp verb(%{type: :episode, episode: episode}), do: Format.episode_verb(episode)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:feed}>
      <h1 class="font-display text-2xl font-bold text-ink">{dgettext("feed", "Activity")}</h1>

      <div class="mt-4 flex flex-wrap gap-1.5">
        <.filter_chip
          :for={period <- @periods}
          active={@period == period}
          phx-click="set_period"
          phx-value-period={period}
        >
          {period_label(period)}
        </.filter_chip>
      </div>

      <div class="mt-4 grid gap-3 sm:grid-cols-3">
        <.stat_tile
          hero
          label={dgettext("feed", "Time watched")}
          value={@watched.value}
          unit={@watched.unit}
        >
          <:foot>{period_note(@period)}</:foot>
        </.stat_tile>

        <.stat_tile
          label={dgettext("feed", "Films")}
          value={to_string(@totals.films)}
          unit={dngettext("feed", "film", "films", @totals.films)}
        >
          <:foot>
            {Format.watch_time(@totals.film_minutes).value} {Format.watch_time(@totals.film_minutes).unit}
          </:foot>
        </.stat_tile>

        <.stat_tile
          label={dgettext("feed", "Series")}
          value={to_string(@totals.series)}
          unit={dgettext("feed", "series")}
        >
          <:foot>
            {dngettext("feed", "%{count} episode", "%{count} episodes", @totals.episodes)} · {Format.watch_time(
              @totals.episode_minutes
            ).value} {Format.watch_time(@totals.episode_minutes).unit}
          </:foot>
        </.stat_tile>
      </div>

      <p :if={@activity == []} class="mt-6 text-ink-soft">
        {dgettext("feed", "Nothing here yet. Go watch something.")}
      </p>

      <div class="mt-6 space-y-8">
        <section :for={{date, items} <- groups(@activity)} class="space-y-3">
          <.section_label>{Format.day_label(date)}</.section_label>

          <.link
            :for={item <- items}
            navigate={~p"/media/#{item.media_item.id}"}
            class="flex gap-3 rounded-2xl bg-paper-2 p-3"
          >
            <div
              class="flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-extrabold text-white"
              style={"background: #{Avatars.color(item.user.id)}"}
            >
              {Avatars.initial(item.user)}
            </div>

            <div class="flex flex-1 flex-col gap-2">
              <div class="text-sm text-ink"><b>{item.user.email}</b> {verb(item)}</div>
              <div class="flex items-center gap-3">
                <.poster
                  src={tmdb_image(item.media_item.poster_path, "w92")}
                  alt={MediaItem.display_title(item.media_item)}
                  framed={false}
                  class="w-10 shrink-0 rounded-lg"
                />
                <div class="flex flex-col gap-1">
                  <div class="font-display text-sm font-bold text-ink">
                    {MediaItem.display_title(item.media_item)}
                  </div>
                  <div class="flex items-center gap-2 text-xs text-ink-soft">
                    <.stars :if={item[:rating]} value={item.rating} />
                    <span :if={is_nil(item.watched_on)}>{Format.time(item.at)}</span>
                  </div>
                </div>
              </div>
            </div>
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
