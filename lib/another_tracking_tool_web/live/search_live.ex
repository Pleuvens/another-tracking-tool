defmodule AnotherTrackingToolWeb.SearchLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.MediaItem

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: [])}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    results =
      case String.trim(q) do
        "" -> []
        query -> query |> Catalog.search() |> to_results()
      end

    {:noreply, assign(socket, query: q, results: results)}
  end

  defp to_results({:ok, items}), do: items
  defp to_results(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:search}>
      <form id="search_form" phx-change="search" phx-submit="search">
        <.search_input
          name="q"
          value={@query}
          placeholder={dgettext("tracking", "Search movies…")}
          phx-debounce="300"
        />
      </form>

      <div class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
        <.link :for={item <- @results} navigate={~p"/media/#{item.id}"}>
          <.poster src={tmdb_image(item.poster_path)} alt={MediaItem.display_title(item)} />
          <div class="mt-2 font-display text-sm font-bold text-ink">
            {MediaItem.display_title(item)}
          </div>
          <div :if={MediaItem.year(item)} class="text-xs text-ink-soft">
            {MediaItem.year(item)}
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
