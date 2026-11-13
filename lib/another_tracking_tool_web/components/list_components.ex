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
    assigns =
      assign(
        assigns,
        :tiles,
        Enum.map(assigns.entries, &tile(&1, assigns.progress, assigns.seasons))
      )

    ~H"""
    <div class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      <.link
        :for={tile <- @tiles}
        navigate={~p"/media/#{tile.entry.media_item_id}"}
        class="flex flex-col gap-2"
      >
        <div class="relative">
          <.poster
            src={tmdb_image(tile.entry.media_item.poster_path)}
            alt={MediaItem.display_title(tile.entry.media_item)}
          />
          <.status_pill
            :if={tile.season}
            status={tile.entry.status}
            label={"S#{tile.season}"}
            class="absolute left-4 top-4"
          />
          <.seen_badge :if={tile.seen?} />
        </div>

        <span class="font-display text-sm font-bold text-ink">
          {MediaItem.display_title(tile.entry.media_item)}
        </span>

        <.episode_progress :if={tile.progress} progress={tile.progress} />
        <.stars :if={tile.rating} value={tile.rating} class="text-xs" />
      </.link>
    </div>
    """
  end

  defp tile(entry, progress_by_item, season_by_item) do
    progress = tracked_progress(Map.get(progress_by_item, entry.media_item_id))

    %{
      entry: entry,
      season: Map.get(season_by_item, entry.media_item_id),
      seen?: entry.status == :completed,
      progress: progress,
      rating: rating_beside_progress(entry.rating, progress)
    }
  end

  defp tracked_progress(%{total: total} = progress) when total > 0, do: progress
  defp tracked_progress(_none), do: nil

  defp rating_beside_progress(rating, nil), do: rating
  defp rating_beside_progress(_rating, _progress), do: nil

  defp seen_badge(assigns) do
    ~H"""
    <span
      title={watch_status_label(:completed)}
      class="absolute right-4 top-4 flex size-6 items-center justify-center rounded-full bg-ink text-paper-0"
    >
      <.icon name="hero-check" class="size-3.5" />
    </span>
    """
  end

  attr :progress, :map, required: true

  defp episode_progress(assigns) do
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

  defp filter_label(:all), do: dgettext("watchlist", "All")
  defp filter_label(status), do: watch_status_label(status)
end
