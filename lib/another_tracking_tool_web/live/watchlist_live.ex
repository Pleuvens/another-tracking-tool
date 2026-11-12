defmodule AnotherTrackingToolWeb.WatchlistLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingTool.WatchStatuses
  alias AnotherTrackingToolWeb.ListComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tracking.subscribe_activity()
    {:ok, socket |> assign(:status, :all) |> load()}
  end

  @impl true
  def handle_event("set_status_filter", %{"status" => status}, socket) do
    {:noreply, socket |> assign(:status, filter_from(status)) |> load()}
  end

  @impl true
  def handle_info({:activity, %{user_id: user_id}}, socket) do
    if user_id == me(socket).id, do: {:noreply, load(socket)}, else: {:noreply, socket}
  end

  defp load(socket) do
    user = me(socket)
    entries = Tracking.my_list(user, socket.assigns.status)
    show_ids = Enum.map(entries, & &1.media_item_id)

    socket
    |> assign(:entries, entries)
    |> assign(:counts, Tracking.status_counts(user))
    |> assign(:progress, Tracking.progress_for(user.id, show_ids))
    |> assign(:seasons, Tracking.current_seasons(user.id, show_ids))
  end

  defp me(socket), do: socket.assigns.current_scope.user

  defp filter_from(status) do
    Enum.find([:all | WatchStatuses.all()], :all, &(Atom.to_string(&1) == status))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:watchlist}>
      <Layouts.page_header>{dgettext("watchlist", "My list")}</Layouts.page_header>

      <ListComponents.status_filters status={@status} counts={@counts} />

      <p :if={@entries == []} class="mt-6 text-ink-soft">
        {empty_message(@status)}
      </p>

      <ListComponents.tile_grid entries={@entries} progress={@progress} seasons={@seasons} />
    </Layouts.app>
    """
  end

  defp empty_message(:all),
    do: dgettext("watchlist", "Nothing planned yet \u2014 go feed it some ideas")

  defp empty_message(_status), do: dgettext("watchlist", "Nothing with that status")
end
