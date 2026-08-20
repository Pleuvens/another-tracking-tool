defmodule AnotherTrackingToolWeb.FeedLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingToolWeb.{Avatars, Format}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tracking.subscribe_activity()
    {:ok, assign(socket, :activity, Tracking.recent_activity())}
  end

  @impl true
  def handle_info({:activity, _entry}, socket) do
    {:noreply, assign(socket, :activity, Tracking.recent_activity())}
  end

  defp groups(activity) do
    activity
    |> Enum.group_by(&DateTime.to_date(&1.at))
    |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})
  end

  defp verb(%{type: :movie, status: status}), do: Format.watch_verb(status)
  defp verb(%{type: :episode, episode: episode}), do: Format.episode_verb(episode)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:feed}>
      <h1 class="font-display text-2xl font-bold text-ink">{dgettext("feed", "Activity")}</h1>

      <p :if={@activity == []} class="mt-6 text-ink-soft">
        {dgettext("feed", "Nothing here yet. Go watch something.")}
      </p>

      <div class="mt-6 space-y-8">
        <section :for={{date, items} <- groups(@activity)} class="space-y-3">
          <div class="text-xs font-extrabold uppercase tracking-widest text-ink-soft">
            {Format.day_label(date)}
          </div>

          <.link
            :for={item <- items}
            navigate={~p"/media/#{item.media_item.id}"}
            class="flex gap-3 rounded-2xl bg-paper-2 p-3"
          >
            <div
              class="flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-extrabold text-white"
              style={"background: #{Avatars.color(item.user.id)}"}
            >
              {Avatars.initial(item.user)}
            </div>

            <div class="flex flex-1 flex-col gap-2">
              <div class="text-sm text-ink"><b>{item.user.email}</b> {verb(item)}</div>
              <div class="flex items-center gap-3">
                <img
                  :if={item.media_item.poster_path}
                  src={tmdb_image(item.media_item.poster_path, "w92")}
                  class="aspect-[2/3] w-10 shrink-0 rounded-lg object-cover"
                />
                <div
                  :if={!item.media_item.poster_path}
                  class="aspect-[2/3] w-10 shrink-0 rounded-lg bg-gradient-to-b from-line to-[oklch(78%_0.02_70)]"
                >
                </div>
                <div class="flex flex-col gap-1">
                  <div class="font-display text-sm font-bold text-ink">
                    {MediaItem.display_title(item.media_item)}
                  </div>
                  <div class="flex items-center gap-2 text-xs text-ink-soft">
                    <.stars :if={item[:rating]} value={item.rating} />
                    <span :if={is_nil(item.watched_on)}>{Format.time(item.at)}</span>
                  </div>
                </div>
              </div>
            </div>
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
