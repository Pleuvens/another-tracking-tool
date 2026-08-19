defmodule AnotherTrackingToolWeb.WatchlistLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Tracking

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tracking.subscribe_activity()
    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:activity, %{user_id: user_id}}, socket) do
    if user_id == me(socket).id, do: {:noreply, load(socket)}, else: {:noreply, socket}
  end

  defp load(socket), do: assign(socket, :entries, Tracking.watchlist(me(socket)))

  defp me(socket), do: socket.assigns.current_scope.user

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:watchlist}>
      <h1 class="font-display text-2xl font-bold text-ink">{dgettext("watchlist", "My list")}</h1>

      <p :if={@entries == []} class="mt-6 text-ink-soft">
        {dgettext("watchlist", "Nothing planned yet — go feed it some ideas")}
      </p>

      <div class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
        <.link :for={entry <- @entries} navigate={~p"/media/#{entry.media_item_id}"}>
          <.poster
            src={tmdb_image(entry.media_item.poster_path)}
            alt={MediaItem.display_title(entry.media_item)}
          />
          <div class="mt-2 font-display text-sm font-bold text-ink">
            {MediaItem.display_title(entry.media_item)}
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
