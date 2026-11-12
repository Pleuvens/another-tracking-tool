defmodule AnotherTrackingToolWeb.MediaLive.Show do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.{Repo, Tracking, WatchStatuses}
  alias AnotherTrackingToolWeb.MediaComponents

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
          <MediaComponents.title_block media_item={@media_item} />
          <MediaComponents.tracking_panel my_entry={@my_entry} editing_date={@editing_date} />
        </div>
      </div>

      <MediaComponents.episodes_panel
        :if={@media_item.kind == :tv}
        seasons={@seasons}
        watched_ids={@watched_ids}
        progress={@progress}
      />

      <MediaComponents.circle_panel entries={@entries} circle_rating={@circle_rating} />
      <MediaComponents.comments_panel comments={@comments} comment_form={@comment_form} />
    </Layouts.app>
    """
  end
end
