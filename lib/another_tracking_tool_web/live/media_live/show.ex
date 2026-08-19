defmodule AnotherTrackingToolWeb.MediaLive.Show do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.{Repo, Tracking, WatchStatuses}
  alias AnotherTrackingToolWeb.Avatars

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Catalog.fetch_media_item(id) do
      {:ok, media_item} ->
        media_item = Repo.preload(media_item, :tmdb_genres)
        if connected?(socket), do: Tracking.subscribe(media_item)
        Catalog.ensure_details(media_item)

        {:ok,
         socket
         |> assign(:media_item, media_item)
         |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
         |> assign(:editing_date, false)
         |> load_tracking()}

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
      nil -> {:noreply, socket}
      status -> Tracking.set_status(me(socket), socket.assigns.media_item, status)
    end

    {:noreply, socket}
  end

  def handle_event("rate", %{"rating" => rating}, socket) do
    Tracking.rate(me(socket), socket.assigns.media_item, String.to_integer(rating))
    {:noreply, socket}
  end

  def handle_event("edit_date", _params, socket) do
    {:noreply, assign(socket, :editing_date, true)}
  end

  def handle_event("set_date", %{"watched_on" => date}, socket) do
    attrs = %{status: :completed, watched_on: date}
    Tracking.upsert_entry(me(socket), socket.assigns.media_item, attrs)
    {:noreply, assign(socket, :editing_date, false)}
  end

  def handle_event("comment", %{"comment" => %{"body" => body}}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      body ->
        Tracking.create_comment(me(socket), socket.assigns.media_item, body)
        {:noreply, assign(socket, :comment_form, to_form(%{"body" => ""}, as: :comment))}
    end
  end

  @impl true
  def handle_info({event, _payload}, socket)
      when event in [:entry_upserted, :entry_deleted, :comment_created, :comment_deleted] do
    {:noreply, load_tracking(socket)}
  end

  defp load_tracking(socket) do
    media_item = socket.assigns.media_item

    socket
    |> assign(:my_entry, Tracking.get_entry(me(socket), media_item))
    |> assign(:entries, Tracking.for_media_item(media_item))
    |> assign(:circle_rating, Tracking.circle_rating(media_item))
    |> assign(:comments, Tracking.list_comments(media_item))
  end

  defp me(socket), do: socket.assigns.current_scope.user

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

          <div class="space-y-3">
            <p class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
              {dgettext("tracking", "My status")}
            </p>
            <div class="flex flex-wrap gap-2">
              <button
                :for={status <- WatchStatuses.all()}
                phx-click="set_status"
                phx-value-status={status}
                class={[
                  "rounded-full px-4 py-1.5 text-sm font-extrabold",
                  if(@my_entry && @my_entry.status == status,
                    do: "bg-ink text-paper-0",
                    else: "bg-paper-2 text-ink-soft hover:text-ink"
                  )
                ]}
              >
                {status_label(status)}
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <p class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
              {dgettext("tracking", "My rating")}
            </p>
            <div class="text-2xl tracking-[4px]">
              <button
                :for={i <- 1..5}
                phx-click="rate"
                phx-value-rating={i}
                class={if i > my_rating(@my_entry), do: "text-line", else: "text-ink"}
              >
                ★
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <p class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
              {dgettext("tracking", "Watched on")}
            </p>
            <div :if={!@editing_date} class="flex items-center gap-3">
              <span class={
                if watched_on(@my_entry), do: "text-ink", else: "text-sm italic text-ink-soft"
              }>
                {watched_label(@my_entry)}
              </span>
              <button phx-click="edit_date" class="text-xs font-bold text-ink-soft hover:text-ink">
                {dgettext("tracking", "Edit")}
              </button>
            </div>
            <form :if={@editing_date} phx-change="set_date">
              <input
                type="date"
                name="watched_on"
                value={watched_on(@my_entry)}
                class="rounded-xl bg-paper-2 px-3 py-2 text-sm text-ink"
              />
            </form>
          </div>
        </div>
      </div>

      <div class="mt-10 space-y-3">
        <p class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
          {dgettext("tracking", "Your circle")}
        </p>
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

      <div class="mt-10 space-y-4">
        <p class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
          {dgettext("tracking", "Comments")}
        </p>

        <.form for={@comment_form} phx-submit="comment" class="flex gap-2">
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
    </Layouts.app>
    """
  end

  defp status_label(:watching), do: dgettext("catalog", "Watching")
  defp status_label(:completed), do: dgettext("catalog", "Completed")
  defp status_label(:dropped), do: dgettext("catalog", "Dropped")
  defp status_label(:planned), do: dgettext("catalog", "Planned")
end
