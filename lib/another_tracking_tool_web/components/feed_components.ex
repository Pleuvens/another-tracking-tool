defmodule AnotherTrackingToolWeb.FeedComponents do
  use AnotherTrackingToolWeb, :html

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.{Episode, MediaItem}
  alias AnotherTrackingToolWeb.{Avatars, Format}

  attr :period, :atom, required: true
  attr :periods, :list, required: true

  def period_chips(assigns) do
    ~H"""
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
    """
  end

  attr :period, :atom, required: true
  attr :totals, :map, required: true
  attr :watched, :map, required: true

  def totals_panel(assigns) do
    ~H"""
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
        <:foot>{Format.watch_time_text(@totals.film_minutes)}</:foot>
      </.stat_tile>

      <.stat_tile
        label={dgettext("feed", "Series")}
        value={to_string(@totals.series)}
        unit={dgettext("feed", "series")}
      >
        <:foot>
          {dngettext("feed", "%{count} episode", "%{count} episodes", @totals.episodes)} · {Format.watch_time_text(
            @totals.episode_minutes
          )}
        </:foot>
      </.stat_tile>
    </div>
    """
  end

  attr :rows, :list, required: true

  def last_watched_list(assigns) do
    ~H"""
    <div class="mt-8 space-y-3">
      <.section_label>{dgettext("feed", "Last watched")}</.section_label>

      <.empty_state :if={@rows == []} title={dgettext("feed", "Nothing here yet")}>
        {dgettext("feed", "Your watches land here as you log them. Start with something of your own.")}
        <:action>
          <.button variant="primary" navigate={~p"/search"}>
            {dgettext("feed", "Find something to watch")}
          </.button>
        </:action>
      </.empty_state>

      <div :if={@rows != []} class="divide-y divide-line-soft rounded-2xl border border-line">
        <.last_watched_row :for={row <- @rows} row={row} />
      </div>
    </div>
    """
  end

  defp last_watched_row(assigns) do
    ~H"""
    <.link
      navigate={~p"/media/#{@row.media_item.id}"}
      class="flex items-center gap-3 p-3 hover:bg-paper-2"
    >
      <.poster
        src={tmdb_image(@row.media_item.poster_path, "w92")}
        alt={MediaItem.display_title(@row.media_item)}
        framed={false}
        class="w-9 shrink-0 rounded-md"
      />

      <div class="flex min-w-0 flex-1 flex-col gap-0.5">
        <span class="font-display text-sm font-bold text-ink">
          {MediaItem.display_title(@row.media_item)}
        </span>
        <span class="truncate text-xs text-ink-soft">{subtitle(@row)}</span>
      </div>

      <div class="flex shrink-0 flex-col items-end gap-1">
        <span class="text-xs text-ink-soft">{Format.day_label(DateTime.to_date(@row.at))}</span>
        <span :if={@row.episodes > 0} class="text-xs font-bold text-ink">
          {dngettext("feed", "%{count} ep", "%{count} ep", @row.episodes)}
        </span>
        <span :if={@row.progress} class="h-0.5 w-14 overflow-hidden rounded-full bg-line">
          <span
            class="block h-full bg-ink"
            style={"width: #{Format.percent(@row.progress.watched, @row.progress.total)}%"}
          ></span>
        </span>
      </div>
    </.link>
    """
  end

  attr :watches, :list, required: true

  def circle_strip(assigns) do
    ~H"""
    <div :if={@watches != []} class="mt-8 space-y-3">
      <.section_label>{dgettext("feed", "Your circle")}</.section_label>

      <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        <.link
          :for={watch <- @watches}
          navigate={~p"/media/#{watch.media_item.id}"}
          class="flex items-center gap-2.5 rounded-xl border border-line p-2.5 hover:bg-paper-2"
        >
          <.avatar initial={Avatars.initial(watch.user)} color={Avatars.color(watch.user.id)} />

          <div class="flex min-w-0 flex-1 flex-col">
            <span class="text-xs font-bold text-ink">{User.display_name(watch.user)}</span>
            <span class="flex items-center gap-1.5 truncate text-xs text-ink-soft">
              {circle_subtitle(watch)}
              <.stars :if={watch.rating} value={watch.rating} class="text-[10px]" />
            </span>
          </div>

          <span class="shrink-0 text-xs text-ink-soft">{Format.ago(watch.at)}</span>
        </.link>
      </div>
    </div>
    """
  end

  defp circle_subtitle(%{episode: %Episode{} = episode, media_item: media_item}),
    do:
      "#{episode.season_number}×#{episode.episode_number} · #{MediaItem.display_title(media_item)}"

  defp circle_subtitle(%{media_item: media_item}), do: MediaItem.display_title(media_item)

  defp subtitle(%{latest_episode: %Episode{} = episode}),
    do:
      dgettext("feed", "up to %{code} · %{name}",
        code: "#{episode.season_number}×#{episode.episode_number}",
        name: episode.name
      )

  defp subtitle(%{media_item: media_item}) do
    [MediaItem.year(media_item), genre(media_item)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp genre(%{tmdb_genres: [genre | _]}), do: genre.name_fr || genre.name_en
  defp genre(_media_item), do: nil

  defp period_label(:month), do: dgettext("feed", "This month")
  defp period_label(:year), do: dgettext("feed", "This year")
  defp period_label(:all), do: dgettext("feed", "All time")

  defp period_note(:month), do: dgettext("feed", "so far this month")
  defp period_note(:year), do: dgettext("feed", "so far this year")
  defp period_note(:all), do: dgettext("feed", "everything you have logged")
end
