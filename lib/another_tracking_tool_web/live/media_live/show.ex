defmodule AnotherTrackingToolWeb.MediaLive.Show do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.{Repo, Tracking, WatchStatuses}
  alias AnotherTrackingToolWeb.{Avatars, Format}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Catalog.fetch_media_item(id) do
      {:ok, media_item} ->
        media_item = Repo.preload(media_item, :tmdb_genres)

        if connected?(socket) do
          Tracking.subscribe(media_item)
          Catalog.subscribe(media_item)
        end

        Catalog.ensure_details(media_item)

        {:ok,
         socket
         |> assign(:media_item, media_item)
         |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
         |> assign(:editing_date, false)
         |> load_tracking()
         |> load_episodes()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, dgettext("tracking", "Not found."))
         |> redirect(to: ~p"/search")}
    end
  end

  @impl true
  def handle_event("set_status", %{"status" => status}, socket) do
    case WatchStatuses.from_string(status) do
      nil ->
        {:noreply, socket}

      status ->
        Tracking.set_status(me(socket), socket.assigns.media_item, status)
        {:noreply, load_tracking(socket)}
    end
  end

  def handle_event("rate", %{"rating" => rating}, socket) do
    Tracking.rate(me(socket), socket.assigns.media_item, String.to_integer(rating))
    {:noreply, load_tracking(socket)}
  end

  def handle_event("edit_date", _params, socket) do
    {:noreply, assign(socket, :editing_date, true)}
  end

  def handle_event("set_date", %{"watched_on" => date}, socket) do
    attrs = %{status: :completed, watched_on: date}
    Tracking.upsert_entry(me(socket), socket.assigns.media_item, attrs)
    {:noreply, socket |> assign(:editing_date, false) |> load_tracking()}
  end

  def handle_event("change_comment", %{"comment" => %{"body" => body}}, socket) do
    {:noreply, assign(socket, :comment_form, to_form(%{"body" => body}, as: :comment))}
  end

  def handle_event("comment", %{"comment" => %{"body" => body}}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      body ->
        Tracking.create_comment(me(socket), socket.assigns.media_item, body)

        {:noreply,
         socket
         |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
         |> load_tracking()}
    end
  end

  def handle_event("toggle_episode", %{"id" => id, "watched" => watched}, socket) do
    episode = Enum.find(all_episodes(socket), &(&1.id == id))

    if episode do
      if watched == "true",
        do: Tracking.unmark_episode(me(socket), episode),
        else: Tracking.mark_episode(me(socket), episode)
    end

    {:noreply, socket |> load_tracking() |> load_episodes()}
  end

  def handle_event("mark_season", %{"season" => season_number}, socket) do
    Tracking.mark_season(me(socket), socket.assigns.media_item, String.to_integer(season_number))
    {:noreply, socket |> load_tracking() |> load_episodes()}
  end

  @impl true
  def handle_info({event, _payload}, socket)
      when event in [:entry_upserted, :entry_deleted, :comment_created, :comment_deleted] do
    {:noreply, load_tracking(socket)}
  end

  def handle_info({event, _payload}, socket)
      when event in [:episode_watched, :episode_unwatched, :episodes_changed, :catalog_updated] do
    {:noreply, socket |> load_tracking() |> load_episodes()}
  end

  defp load_tracking(socket) do
    media_item = socket.assigns.media_item

    socket
    |> assign(:my_entry, Tracking.get_entry(me(socket), media_item))
    |> assign(:entries, Tracking.for_media_item(media_item))
    |> assign(:circle_rating, Tracking.circle_rating(media_item))
    |> assign(:comments, Tracking.list_comments(media_item))
  end

  defp load_episodes(%{assigns: %{media_item: %{kind: :tv} = media_item}} = socket) do
    socket
    |> assign(:seasons, Catalog.seasons_with_episodes(media_item))
    |> assign(:watched_ids, Tracking.watched_episode_ids(me(socket), media_item))
    |> assign(:progress, Tracking.episode_progress(me(socket), media_item))
  end

  defp load_episodes(socket),
    do: assign(socket, seasons: [], watched_ids: MapSet.new(), progress: %{watched: 0, total: 0})

  defp all_episodes(socket), do: Enum.flat_map(socket.assigns.seasons, & &1.episodes)

  defp me(socket), do: socket.assigns.current_scope.user

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="grid items-start gap-8 sm:grid-cols-[220px_1fr]">
        <.poster
          src={tmdb_image(@media_item.poster_path, "w500")}
          alt={MediaItem.display_title(@media_item)}
        />

        <div class="space-y-5">
          <.title_block media_item={@media_item} />
          <.tracking_panel my_entry={@my_entry} editing_date={@editing_date} />
        </div>
      </div>

      <.episodes_panel
        :if={@media_item.kind == :tv}
        seasons={@seasons}
        watched_ids={@watched_ids}
        progress={@progress}
      />

      <.circle_panel entries={@entries} circle_rating={@circle_rating} />
      <.comments_panel comments={@comments} comment_form={@comment_form} />
    </Layouts.app>
    """
  end

  defp title_block(assigns) do
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

  defp tracking_panel(assigns) do
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

  defp episodes_panel(assigns) do
    ~H"""
    <div class="mt-10 space-y-4">
      <div class="flex items-center justify-between">
        <.section_label>{dgettext("tracking", "Episodes")}</.section_label>
        <span class="text-xs text-ink-soft">{@progress.watched}/{@progress.total}</span>
      </div>
      <div class="h-2 overflow-hidden rounded-full bg-paper-2">
        <div
          class="h-full bg-ink transition-all"
          style={"width: #{Format.percent(@progress.watched, @progress.total)}%"}
        >
        </div>
      </div>

      <p :if={@seasons == []} class="text-sm text-ink-soft">
        {dgettext("tracking", "Episodes are still loading…")}
      </p>

      <div :for={season <- @seasons} class="space-y-2">
        <div class="flex items-center justify-between">
          <h3 class="font-display font-bold text-ink">
            {season.name || dgettext("tracking", "Season %{n}", n: season.season_number)}
          </h3>
          <button
            phx-click="mark_season"
            phx-value-season={season.season_number}
            class="text-xs font-bold text-ink-soft hover:text-ink"
          >
            {dgettext("tracking", "Mark season watched")}
          </button>
        </div>
        <.episode_row
          :for={episode <- season.episodes}
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
        "flex w-full items-center gap-3 rounded-xl bg-paper-2 px-3 py-2 text-left text-sm",
        if(@watched, do: "text-ink", else: "text-ink-soft hover:text-ink")
      ]}
    >
      <span class="w-8 shrink-0 font-bold tabular-nums">
        {@episode.season_number}×{@episode.episode_number}
      </span>
      <span class="flex-1 truncate">{@episode.name}</span>
      <.icon :if={@watched} name="hero-check-circle-solid" class="size-5 text-ink" />
    </button>
    """
  end

  defp circle_panel(assigns) do
    ~H"""
    <div class="mt-10 space-y-3">
      <.section_label>{dgettext("tracking", "Your circle")}</.section_label>
      <div class="flex items-center gap-4">
        <.avatar_stack people={circle_avatars(@entries)} extra={max(length(@entries) - 5, 0)} />
        <span :if={@circle_rating} class="font-display font-bold text-ink">
          {@circle_rating} / 5
        </span>
        <span :if={@entries == []} class="text-sm text-ink-soft">
          {dgettext("tracking", "No one yet — be the first.")}
        </span>
      </div>
    </div>
    """
  end

  defp comments_panel(assigns) do
    ~H"""
    <div class="mt-10 space-y-4">
      <.section_label>{dgettext("tracking", "Comments")}</.section_label>

      <.form
        for={@comment_form}
        id="comment_form"
        phx-change="change_comment"
        phx-submit="comment"
        class="flex gap-2"
      >
        <input
          type="text"
          name="comment[body]"
          value={@comment_form[:body].value}
          placeholder={dgettext("tracking", "Say something…")}
          class="flex-1 rounded-full bg-paper-2 px-5 py-3 text-sm text-ink placeholder:text-ink-soft focus:outline-none"
        />
        <.button variant="primary">{dgettext("tracking", "Post")}</.button>
      </.form>

      <div :for={comment <- @comments} class="rounded-2xl bg-paper-2 p-4">
        <div class="text-xs font-bold text-ink-soft">{comment.user.email}</div>
        <div class="text-ink">{comment.body}</div>
      </div>
    </div>
    """
  end
end
