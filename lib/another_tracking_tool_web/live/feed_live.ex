defmodule AnotherTrackingToolWeb.FeedLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingToolWeb.{FeedComponents, Format}

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
  def handle_info({:activity, _subject}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    totals = Tracking.watch_totals(me(socket), socket.assigns.period)

    socket
    |> assign(:last_watched, Tracking.last_watched(me(socket), socket.assigns.period))
    |> assign(:circle, Tracking.circle_latest(me(socket)))
    |> assign(:totals, totals)
    |> assign(:watched, Format.watch_time(totals.minutes))
  end

  defp me(socket), do: socket.assigns.current_scope.user

  defp period_from(period), do: Enum.find(@periods, :month, &(Atom.to_string(&1) == period))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:feed}>
      <Layouts.page_header>{dgettext("feed", "Activity")}</Layouts.page_header>

      <FeedComponents.period_chips period={@period} periods={@periods} />
      <FeedComponents.totals_panel period={@period} totals={@totals} watched={@watched} />
      <FeedComponents.last_watched_list rows={@last_watched} />
      <FeedComponents.circle_strip watches={@circle} />
    </Layouts.app>
    """
  end
end
