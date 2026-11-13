defmodule AnotherTrackingToolWeb.ListComponents do
  use AnotherTrackingToolWeb, :html

  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.WatchStatuses
  alias AnotherTrackingToolWeb.Format

  attr :status, :atom, required: true
  attr :counts, :map, required: true

  def status_filters(assigns) do
    ~H"""
    <div class="mt-4 flex flex-wrap gap-1.5">
      <.filter_chip
        :for={status <- [:all | WatchStatuses.all()]}
        active={@status == status}
        phx-click="set_status_filter"
        phx-value-status={status}
      >
        {filter_label(status)} · {Map.fetch!(@counts, status)}
      </.filter_chip>
    </div>
    """
  end

  attr :entries, :list, required: true
  attr :progress, :map, required: true
  attr :seasons, :map, required: true

  def tile_grid(assigns) do
    ~H"""
    <div class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      <.link
        :for={entry <- @entries}
        navigate={~p"/media/#{entry.media_item_id}"}
        class="flex flex-col gap-2"
      >
        <div class="relative">
          <.poster
            src={tmdb_image(entry.media_item.poster_path)}
            alt={MediaItem.display_title(entry.media_item)}
          />
          <.status_pill
            :if={season(@seasons, entry)}
            status={entry.status}
            label={"S#{season(@seasons, entry)}"}
            class="absolute left-4 top-4"
          />
          <span
            :if={entry.status == :completed}
            title={watch_status_label(:completed)}
            class="absolute right-4 top-4 flex size-6 items-center justify-center rounded-full bg-ink text-paper-0"
          >
            <.icon name="hero-check" class="size-3.5" />
          </span>
        </div>

        <span class="font-display text-sm font-bold text-ink">
          {MediaItem.display_title(entry.media_item)}
        </span>

        <.tile_state entry={entry} progress={Map.get(@progress, entry.media_item_id)} />
      </.link>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :progress, :map, default: nil

  defp tile_state(%{progress: %{total: total}} = assigns) when total > 0 do
    ~H"""
    <span class="flex flex-col gap-1.5">
      <span class="h-0.5 overflow-hidden rounded-full bg-line">
        <span
          class="block h-full bg-ink"
          style={"width: #{Format.percent(@progress.watched, @progress.total)}%"}
        ></span>
      </span>
      <span class="text-xs text-ink-soft">
        {dgettext("watchlist", "%{watched} of %{total} episodes",
          watched: @progress.watched,
          total: @progress.total
        )}
      </span>
    </span>
    """
  end

  defp tile_state(%{entry: %{rating: rating}} = assigns) when not is_nil(rating) do
    ~H"""
    <.stars value={@entry.rating} class="text-xs" />
    """
  end

  defp tile_state(assigns), do: ~H""

  defp season(seasons, entry), do: Map.get(seasons, entry.media_item_id)

  defp filter_label(:all), do: dgettext("watchlist", "All")
  defp filter_label(status), do: watch_status_label(status)
end
