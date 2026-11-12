defmodule AnotherTrackingToolWeb.DiscoverComponents do
  use AnotherTrackingToolWeb, :html

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem

  @decisions [
    {:completed, "hero-check", "↑"},
    {:watching, "hero-clock", "↓"},
    {:planned, "hero-bookmark", "→"},
    {:not_interested, "hero-x-mark", "←"}
  ]

  def decisions, do: @decisions

  attr :cards, :list, required: true

  def deck(assigns) do
    ~H"""
    <div class="relative mx-auto aspect-[3/4] w-full max-w-sm">
      <.card
        :for={{card, depth} <- Enum.with_index(@cards) |> Enum.reverse()}
        card={card}
        depth={depth}
      />
    </div>
    """
  end

  attr :card, :map, required: true
  attr :depth, :integer, required: true

  defp card(assigns) do
    ~H"""
    <article
      class={[
        "absolute inset-0 flex flex-col overflow-hidden rounded-2xl border border-line bg-paper-0",
        @depth > 0 && "pointer-events-none"
      ]}
      style={"transform: translateY(#{@depth * -8}px) scale(#{1 - @depth * 0.035}); opacity: #{1 - @depth * 0.35}"}
    >
      <div class="relative flex-1">
        <.poster
          src={tmdb_image(@card.media_item.poster_path, "w500")}
          alt={MediaItem.display_title(@card.media_item)}
          framed={false}
          class="size-full"
        />
        <span class="absolute left-3 top-3 rounded-full bg-ink/70 px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-widest text-paper-0">
          {kind_label(@card.media_item)}
        </span>
      </div>

      <div class="flex flex-col items-start gap-2 p-4">
        <span class="flex items-center gap-1.5 rounded-full bg-paper-2 px-2.5 py-1 text-[11px] font-bold text-ink-soft">
          <.icon name="hero-sparkles" class="size-3" />
          <.reason reason={@card.reason} />
        </span>

        <h2 class="font-display text-xl font-bold leading-tight text-ink">
          {MediaItem.display_title(@card.media_item)}
        </h2>

        <div class="flex flex-wrap items-center gap-2 text-xs text-ink-soft">
          <span>{meta(@card.media_item)}</span>
          <span
            :for={genre <- Enum.take(@card.media_item.tmdb_genres, 2)}
            class="rounded-full border border-line px-2 py-0.5 text-[10px] font-bold"
          >
            {genre_name(genre)}
          </span>
        </div>

        <p
          :if={MediaItem.display_overview(@card.media_item)}
          class="line-clamp-3 text-xs text-ink-soft"
        >
          {MediaItem.display_overview(@card.media_item)}
        </p>

        <.link
          navigate={~p"/media/#{@card.media_item.id}"}
          class="rounded-full border border-line px-3 py-1 text-xs font-bold text-ink-soft hover:text-ink"
        >
          {dgettext("tracking", "Open page")}
        </.link>
      </div>
    </article>
    """
  end

  attr :reason, :any, required: true

  defp reason(%{reason: {:top_genre, genre}} = assigns) do
    assigns = assign(assigns, :genre, genre_name(genre))

    ~H"""
    {dgettext("tracking", "Your most-watched genre: %{genre}", genre: @genre)}
    """
  end

  defp reason(%{reason: {:frequent_genre, genre}} = assigns) do
    assigns = assign(assigns, :genre, genre_name(genre))

    ~H"""
    {dgettext("tracking", "You watch a lot of %{genre}", genre: @genre)}
    """
  end

  defp reason(%{reason: {:circle, user, rating}} = assigns) do
    assigns = assigns |> assign(:name, User.display_name(user)) |> assign(:rating, rating)

    ~H"""
    {dgettext("tracking", "%{name} rated it", name: @name)}
    <.stars value={@rating} class="text-[10px]" />
    """
  end

  defp reason(%{reason: :new} = assigns) do
    ~H"""
    {dgettext("tracking", "New ground for you")}
    """
  end

  attr :media_item_id, :string, required: true

  def decision_row(assigns) do
    ~H"""
    <div class="mx-auto grid w-full max-w-md grid-cols-2 gap-2 sm:grid-cols-4">
      <button
        :for={{status, icon, hint} <- decisions()}
        phx-click="decide"
        phx-value-id={@media_item_id}
        phx-value-status={status}
        class="flex flex-col items-center gap-1 rounded-xl border border-line bg-paper-0 px-2 py-2.5 text-[11px] font-bold text-ink-soft hover:border-ink hover:text-ink"
      >
        <.icon name={icon} class="size-4" />
        <span class="text-ink">{watch_status_label(status)}</span>
        <kbd class="rounded border border-line px-1 text-[9px]">{hint}</kbd>
      </button>
    </div>
    """
  end

  attr :decision, :map, default: nil

  def decided_bar(assigns) do
    ~H"""
    <div
      :if={@decision}
      class="mx-auto flex w-full max-w-md flex-wrap items-center justify-center gap-3 rounded-full border border-line bg-paper-0 px-4 py-2"
    >
      <span class="flex items-center gap-2 text-xs text-ink">
        {MediaItem.display_title(@decision.media_item)}
        <.status_pill status={@decision.status} />
      </span>

      <div :if={@decision.status == :completed} class="flex text-base leading-none">
        <button
          :for={i <- 1..5}
          phx-click="rate"
          phx-value-rating={i}
          class={if i > @decision.rating, do: "text-line hover:text-ink", else: "text-ink"}
        >
          ★
        </button>
      </div>

      <button
        phx-click="undo"
        class="rounded-full border border-line px-3 py-0.5 text-xs font-bold text-ink-soft hover:text-ink"
      >
        {dgettext("tracking", "Undo")}
      </button>
    </div>
    """
  end

  attr :results, :list, required: true
  attr :query, :string, required: true

  def results_grid(assigns) do
    ~H"""
    <div :if={@results != []} class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
      <.link :for={result <- @results} navigate={~p"/media/#{result.media_item.id}"}>
        <.poster
          src={tmdb_image(result.media_item.poster_path)}
          alt={MediaItem.display_title(result.media_item)}
        />
        <div class="mt-2 font-display text-sm font-bold text-ink">
          {MediaItem.display_title(result.media_item)}
        </div>
        <div class="mt-1 text-xs text-ink-soft">
          <.status_pill :if={result.status} status={result.status} />
          <span :if={is_nil(result.status)}>{meta(result.media_item)}</span>
        </div>
      </.link>
    </div>
    """
  end

  defp kind_label(%{kind: :tv}), do: dgettext("tracking", "Series")
  defp kind_label(_media_item), do: dgettext("tracking", "Film")

  defp meta(%{kind: :tv} = media_item) do
    [MediaItem.year(media_item), episode_count(media_item)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp meta(media_item) do
    [MediaItem.year(media_item), runtime(media_item)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp episode_count(%{episodes: episodes}) when is_list(episodes) do
    dngettext("tracking", "%{count} episode", "%{count} episodes", length(episodes))
  end

  defp episode_count(_media_item), do: nil

  defp runtime(%{runtime: nil}), do: nil
  defp runtime(%{runtime: minutes}), do: dgettext("tracking", "%{count} min", count: minutes)

  defp genre_name(genre), do: genre.name_fr || genre.name_en
end
