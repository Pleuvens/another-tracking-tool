defmodule AnotherTrackingToolWeb.MediaComponents do
  use AnotherTrackingToolWeb, :html

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.WatchStatuses
  alias AnotherTrackingToolWeb.{Avatars, Format}

  attr :media_item, :map, required: true

  def title_block(assigns) do
    ~H"""
    <div class="space-y-5">
      <div>
        <h1 class="font-display text-3xl font-bold text-ink">
          {MediaItem.display_title(@media_item)}
        </h1>
        <p :if={MediaItem.year(@media_item)} class="text-ink-soft">
          {MediaItem.year(@media_item)}
        </p>
      </div>

      <div :if={@media_item.tmdb_genres != []} class="flex flex-wrap gap-2">
        <span
          :for={genre <- @media_item.tmdb_genres}
          class="rounded-full bg-paper-2 px-3 py-1 text-xs font-bold text-ink-soft"
        >
          {genre.name_fr || genre.name_en}
        </span>
      </div>

      <p :if={MediaItem.display_overview(@media_item)} class="leading-relaxed text-ink">
        {MediaItem.display_overview(@media_item)}
      </p>
    </div>
    """
  end

  attr :my_entry, :map, default: nil
  attr :editing_date, :boolean, default: false

  def tracking_panel(assigns) do
    ~H"""
    <div class="flex flex-wrap items-start gap-x-8 gap-y-4 rounded-2xl border border-line bg-paper-0 p-4">
      <div class="flex flex-col gap-2">
        <.section_label>{dgettext("tracking", "Status")}</.section_label>
        <.status_control my_entry={@my_entry} />
      </div>

      <div class="flex flex-col gap-2">
        <.section_label>{dgettext("tracking", "Rating")}</.section_label>
        <div class="flex text-xl leading-none tracking-[3px]">
          <button
            :for={i <- 1..5}
            phx-click="rate"
            phx-value-rating={i}
            class={if i > my_rating(@my_entry), do: "text-line hover:text-ink", else: "text-ink"}
          >
            ★
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <.section_label>{dgettext("tracking", "Watched on")}</.section_label>
        <button
          :if={!@editing_date}
          phx-click="edit_date"
          class={[
            "rounded-xl border border-dashed border-line px-3 py-1 text-sm hover:border-solid",
            if(watched_on(@my_entry), do: "text-ink", else: "italic text-ink-soft")
          ]}
        >
          {watched_label(@my_entry)}
        </button>
        <form :if={@editing_date} phx-change="set_date">
          <input
            type="date"
            name="watched_on"
            value={watched_on(@my_entry)}
            class="rounded-xl bg-paper-2 px-3 py-1 text-sm text-ink"
          />
        </form>
      </div>
    </div>
    """
  end

  defp status_control(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-0.5 rounded-full bg-paper-2 p-0.5">
      <button
        :for={status <- WatchStatuses.all()}
        phx-click="set_status"
        phx-value-status={status}
        aria-pressed={to_string(chosen?(@my_entry, status))}
        class={[
          "rounded-full px-3 py-1 text-xs font-bold",
          if(chosen?(@my_entry, status),
            do: "bg-ink text-paper-0",
            else: "text-ink-soft hover:text-ink"
          )
        ]}
      >
        {watch_status_label(status)}
      </button>
    </div>
    """
  end

  attr :seasons, :list, required: true
  attr :watched_ids, :any, required: true
  attr :progress, :map, required: true
  attr :open_seasons, :any, required: true

  def episodes_panel(assigns) do
    ~H"""
    <div class="mt-10 space-y-4">
      <div class="flex items-center justify-between">
        <.section_label>{dgettext("tracking", "Episodes")}</.section_label>
        <span class="text-xs text-ink-soft">
          {dgettext("tracking", "%{watched} of %{total} watched",
            watched: @progress.watched,
            total: @progress.total
          )}
        </span>
      </div>

      <p :if={@seasons == []} class="text-sm text-ink-soft">
        {dgettext("tracking", "Episodes are still loading…")}
      </p>

      <.season_block
        :for={season <- Enum.sort_by(@seasons, & &1.season_number, :desc)}
        season={season}
        watched_ids={@watched_ids}
        open={MapSet.member?(@open_seasons, season.season_number)}
      />
    </div>
    """
  end

  attr :season, :map, required: true
  attr :watched_ids, :any, required: true
  attr :open, :boolean, required: true

  defp season_block(assigns) do
    assigns =
      assigns
      |> assign(:watched, watched_in(assigns.season, assigns.watched_ids))
      |> assign(:total, length(assigns.season.episodes))

    ~H"""
    <div class="overflow-hidden rounded-xl border border-line">
      <div class="flex flex-wrap items-center gap-3 bg-paper-0 p-3">
        <button
          phx-click="toggle_season"
          phx-value-season={@season.season_number}
          aria-expanded={to_string(@open)}
          class="flex min-w-36 flex-1 items-center gap-2.5 text-left"
        >
          <.icon
            name="hero-chevron-right"
            class={["size-3.5 shrink-0 text-ink-soft transition-transform", @open && "rotate-90"]}
          />
          <b class="font-display text-sm text-ink">{season_name(@season)}</b>
          <span class="h-0.5 max-w-36 flex-1 overflow-hidden rounded-full bg-line">
            <span class="block h-full bg-ink" style={"width: #{Format.percent(@watched, @total)}%"}></span>
          </span>
          <span class="shrink-0 text-xs tabular-nums text-ink-soft">{@watched}/{@total}</span>
        </button>

        <button
          phx-click={if @watched == @total, do: "unmark_season", else: "mark_season"}
          phx-value-season={@season.season_number}
          class="rounded-full border border-line px-2.5 py-0.5 text-[11px] font-bold text-ink-soft hover:text-ink"
        >
          {if @watched == @total,
            do: dgettext("tracking", "Clear season"),
            else: dgettext("tracking", "Mark season watched")}
        </button>
      </div>

      <div :if={@open} class="divide-y divide-line-soft border-t border-line">
        <.episode_row
          :for={episode <- @season.episodes}
          episode={episode}
          watched={MapSet.member?(@watched_ids, episode.id)}
        />
      </div>
    </div>
    """
  end

  defp episode_row(assigns) do
    ~H"""
    <button
      phx-click="toggle_episode"
      phx-value-id={@episode.id}
      phx-value-watched={to_string(@watched)}
      class={[
        "flex w-full items-center gap-3 px-3 py-2 text-left text-sm hover:bg-paper-2",
        if(@watched, do: "text-ink", else: "text-ink-soft")
      ]}
    >
      <span class="w-10 shrink-0 font-bold tabular-nums">
        {@episode.season_number}×{@episode.episode_number}
      </span>
      <span class="flex-1 truncate">{@episode.name}</span>
      <.icon :if={@watched} name="hero-check-circle-solid" class="size-5 shrink-0 text-ink" />
    </button>
    """
  end

  defp season_name(%{name: nil, season_number: number}),
    do: dgettext("tracking", "Season %{n}", n: number)

  defp season_name(%{name: name}), do: name

  defp watched_in(season, watched_ids),
    do: Enum.count(season.episodes, &MapSet.member?(watched_ids, &1.id))

  attr :entries, :list, required: true
  attr :circle_rating, :any, default: nil

  def circle_panel(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 rounded-2xl border border-line bg-paper-0 p-4">
      <.section_label>{dgettext("tracking", "Your circle")}</.section_label>

      <p :if={@entries == []} class="text-sm text-ink-soft">
        {dgettext("tracking", "No one yet — be the first.")}
      </p>

      <div :if={@entries != []} class="flex items-center gap-3">
        <.avatar_stack people={circle_avatars(@entries)} extra={max(length(@entries) - 5, 0)} />
        <span :if={@circle_rating} class="font-display text-xl font-bold text-ink">
          {@circle_rating}
          <span class="text-xs font-semibold text-ink-soft">/ 5</span>
        </span>
      </div>

      <div :if={@entries != []} class="flex flex-col gap-2">
        <div :for={entry <- @entries} class="flex items-center justify-between gap-3 text-sm">
          <span class="truncate text-ink-soft">{User.display_name(entry.user)}</span>
          <.stars :if={entry.rating} value={entry.rating} class="shrink-0 text-xs" />
          <.status_pill :if={is_nil(entry.rating)} status={entry.status} />
        </div>
      </div>
    </div>
    """
  end

  attr :comments, :list, required: true
  attr :comment_form, :map, required: true

  def comments_panel(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 rounded-2xl border border-line bg-paper-0 p-4">
      <.section_label>{dgettext("tracking", "Comments")}</.section_label>

      <p :if={@comments == []} class="text-sm text-ink-soft">
        {dgettext("tracking", "No one has said anything yet.")}
      </p>

      <div :for={comment <- @comments} class="flex gap-2 text-sm">
        <.avatar
          initial={Avatars.initial(comment.user)}
          color={Avatars.color(comment.user.id)}
          class="size-6"
        />
        <div class="flex min-w-0 flex-col">
          <span class="text-xs font-bold text-ink-soft">{User.display_name(comment.user)}</span>
          <p class="break-words text-ink">{comment.body}</p>
        </div>
      </div>

      <.form
        for={@comment_form}
        id="comment_form"
        phx-change="change_comment"
        phx-submit="comment"
        class="flex items-center gap-2"
      >
        <input
          type="text"
          name="comment[body]"
          value={@comment_form[:body].value}
          placeholder={dgettext("tracking", "Say something…")}
          class="min-w-0 flex-1 rounded-full bg-paper-2 px-4 py-2 text-sm text-ink placeholder:text-ink-soft focus:outline-none"
        />
        <.button variant="primary">{dgettext("tracking", "Post")}</.button>
      </.form>
    </div>
    """
  end

  defp chosen?(%{status: status}, status), do: true
  defp chosen?(_entry, _status), do: false

  defp my_rating(nil), do: 0
  defp my_rating(%{rating: nil}), do: 0
  defp my_rating(%{rating: rating}), do: rating

  defp watched_on(%{watched_on: %Date{} = date}), do: date
  defp watched_on(_), do: nil

  defp watched_label(entry) do
    case watched_on(entry) do
      %Date{} = date -> Calendar.strftime(date, "%d/%m/%Y")
      nil -> dgettext("tracking", "Sometime, who's counting")
    end
  end

  defp circle_avatars(entries),
    do: entries |> Enum.map(& &1.user) |> Enum.take(5) |> Avatars.for_users()
end
