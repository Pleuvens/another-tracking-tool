defmodule AnotherTrackingToolWeb.SearchLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.{Catalog, Tracking}
  alias AnotherTrackingToolWeb.DiscoverComponents

  @deck_depth 3

  @keys %{
    "ArrowUp" => :completed,
    "ArrowDown" => :watching,
    "ArrowRight" => :planned,
    "ArrowLeft" => :not_interested
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(query: "", results: [], decision: nil) |> load_deck()}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    case String.trim(q) do
      "" -> {:noreply, socket |> assign(query: q, results: []) |> load_deck()}
      query -> {:noreply, assign(socket, query: q, results: search(query, socket))}
    end
  end

  def handle_event("decide", %{"id" => id, "status" => status}, socket) do
    {:noreply, decide(socket, id, String.to_existing_atom(status))}
  end

  def handle_event("decide_by_key", %{"key" => key}, socket) do
    case {Map.get(@keys, key), socket.assigns.cards} do
      {nil, _cards} -> {:noreply, socket}
      {_status, []} -> {:noreply, socket}
      {status, [card | _rest]} -> {:noreply, decide(socket, card.media_item.id, status)}
    end
  end

  def handle_event("rate", %{"rating" => rating}, socket) do
    decision = socket.assigns.decision
    rating = String.to_integer(rating)
    {:ok, _entry} = Tracking.rate(me(socket), decision.media_item, rating)

    {:noreply, assign(socket, :decision, %{decision | rating: rating})}
  end

  def handle_event("undo", _params, socket) do
    decision = socket.assigns.decision
    undo(me(socket), decision)

    {:noreply, socket |> assign(:decision, nil) |> load_deck()}
  end

  defp decide(socket, media_item_id, status) do
    user = me(socket)

    with {:ok, media_item} <- Catalog.fetch_media_item(media_item_id) do
      previous = Tracking.get_entry(user, media_item)
      {:ok, entry} = Tracking.set_status(user, media_item, status)

      socket
      |> assign(:decision, %{
        media_item: media_item,
        status: status,
        rating: entry.rating || 0,
        previous: previous && previous.status
      })
      |> load_deck()
    else
      {:error, :not_found} -> load_deck(socket)
    end
  end

  defp undo(user, %{previous: nil, media_item: media_item}),
    do: Tracking.delete_entry(user, media_item)

  defp undo(user, %{previous: previous, media_item: media_item}),
    do: Tracking.set_status(user, media_item, previous)

  defp load_deck(socket) do
    cards = Tracking.suggestions(me(socket), @deck_depth)
    totals = Tracking.progress_for(me(socket).id, series_ids(cards))

    assign(socket, :cards, Enum.map(cards, &Map.put(&1, :episodes, episodes_of(totals, &1))))
  end

  defp series_ids(cards) do
    for %{media_item: %{kind: :tv, id: id}} <- cards, do: id
  end

  defp episodes_of(totals, %{media_item: %{id: id}}) do
    case Map.get(totals, id) do
      %{total: total} when total > 0 -> total
      _missing -> nil
    end
  end

  defp search(query, socket) do
    case Catalog.search(query) do
      {:ok, items} -> Enum.map(items, &%{media_item: &1, status: status_of(socket, &1)})
      _error -> []
    end
  end

  defp status_of(socket, media_item) do
    entry = Tracking.get_entry(me(socket), media_item)
    entry && entry.status
  end

  defp me(socket), do: socket.assigns.current_scope.user

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:search}>
      <Layouts.page_header search={false}>{dgettext("tracking", "Discover")}</Layouts.page_header>

      <form id="search_form" class="mt-4" phx-change="search" phx-submit="search">
        <.search_input
          name="q"
          value={@query}
          placeholder={dgettext("tracking", "Or search by name")}
          phx-debounce="300"
        />
      </form>

      <div
        :if={@query == ""}
        id="deck"
        class="mt-6 flex flex-col gap-4"
        phx-window-keydown="decide_by_key"
      >
        <%= if @cards == [] do %>
          <div class="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line p-8 text-center">
            <b class="font-display text-lg text-ink">
              {dgettext("tracking", "That is every suggestion")}
            </b>
            <span class="text-sm text-ink-soft">
              {dgettext(
                "tracking",
                "You have made a call on everything we know about. Search for something by name instead."
              )}
            </span>
          </div>
        <% else %>
          <DiscoverComponents.deck cards={@cards} />
          <DiscoverComponents.decision_row media_item_id={hd(@cards).media_item.id} />
          <p class="text-center text-[11px] text-ink-soft">
            {dgettext("tracking", "Use the buttons or the arrow keys.")}
          </p>
        <% end %>

        <DiscoverComponents.decided_bar decision={@decision} />
      </div>

      <p :if={@query != "" and @results == []} class="mt-6 text-sm text-ink-soft">
        {dgettext("tracking", "No match for “%{query}”", query: @query)}
      </p>

      <DiscoverComponents.results_grid results={@results} query={@query} />
    </Layouts.app>
    """
  end
end
