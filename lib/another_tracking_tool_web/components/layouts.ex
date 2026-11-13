defmodule AnotherTrackingToolWeb.Layouts do
  use AnotherTrackingToolWeb, :html

  alias AnotherTrackingTool.Accounts
  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingToolWeb.Avatars

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :active, :atom, default: nil
  slot :inner_block, required: true

  def app(%{current_scope: nil} = assigns) do
    ~H"""
    <header class="border-b border-line">
      <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
        <a href="/">
          <.wordmark />
        </a>
        <nav class="flex items-center gap-5 text-sm font-bold text-ink-soft">
          <.link :if={Accounts.first_user?()} navigate={~p"/users/register"} class="hover:text-ink">
            {dgettext("layouts", "Register")}
          </.link>
          <.link navigate={~p"/users/log-in"} class="hover:text-ink">
            {dgettext("layouts", "Log in")}
          </.link>
        </nav>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  def app(assigns) do
    assigns = assign(assigns, :counts, nav_counts(assigns.current_scope.user))

    ~H"""
    <div class="md:flex md:min-h-screen">
      <header class="flex items-center gap-3 border-b border-line px-4 py-3 md:hidden">
        <button
          phx-click={toggle_menu()}
          aria-controls="side-menu"
          aria-label={dgettext("layouts", "Open menu")}
          class="text-ink-soft hover:text-ink"
        >
          <.icon name="hero-bars-3" class="size-5" />
        </button>
        <.wordmark />
      </header>

      <div
        id="side-menu-backdrop"
        phx-click={toggle_menu()}
        class="fixed inset-0 z-30 hidden bg-ink/40 md:hidden"
      >
      </div>

      <aside
        id="side-menu"
        class="fixed inset-y-0 left-0 z-40 w-60 -translate-x-full overflow-y-auto border-r border-line bg-paper-0 transition-transform md:static md:w-56 md:shrink-0 md:translate-x-0"
      >
        <div class="flex flex-col gap-5 p-4 md:h-full">
          <.wordmark mark class="px-2" />

          <.nav_group label={dgettext("layouts", "Watch")}>
            <.nav_item navigate={~p"/feed"} icon="hero-chart-bar" active={@active == :feed}>
              {dgettext("layouts", "Activity")}
            </.nav_item>
            <.nav_item
              navigate={~p"/search"}
              icon="hero-magnifying-glass"
              active={@active == :search}
            >
              {dgettext("layouts", "Discover")}
            </.nav_item>
            <.nav_item
              navigate={~p"/watchlist"}
              icon="hero-bookmark"
              active={@active == :watchlist}
              count={@counts.list}
            >
              {dgettext("layouts", "My list")}
            </.nav_item>
          </.nav_group>

          <.nav_group label={dgettext("layouts", "You")}>
            <.nav_item
              navigate={~p"/users/settings"}
              icon="hero-user-circle"
              active={@active == :profile}
            >
              {dgettext("layouts", "Profile")}
            </.nav_item>
            <.nav_item
              navigate={~p"/import"}
              icon="hero-arrow-down-tray"
              active={@active == :import}
            >
              {dgettext("layouts", "Import")}
            </.nav_item>
          </.nav_group>

          <.nav_group :if={@current_scope.user.admin} label={dgettext("layouts", "Admin")}>
            <.nav_item
              navigate={~p"/invites"}
              icon="hero-envelope"
              active={@active == :invites}
              count={@counts.invites}
            >
              {dgettext("layouts", "Invites")}
            </.nav_item>
            <.nav_item
              navigate={~p"/integrations"}
              icon="hero-puzzle-piece"
              active={@active == :integrations}
            >
              {dgettext("layouts", "Integrations")}
            </.nav_item>
          </.nav_group>

          <div class="flex items-center gap-2 border-t border-line px-2 pt-3 md:mt-auto">
            <.avatar
              initial={Avatars.initial(@current_scope.user)}
              color={Avatars.color(@current_scope.user.id)}
              class="size-7"
            />
            <div class="flex min-w-0 flex-col">
              <span class="truncate text-xs font-bold text-ink">
                {User.display_name(@current_scope.user)}
              </span>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="text-left text-[11px] text-ink-soft hover:text-ink"
              >
                {dgettext("layouts", "Log out")}
              </.link>
            </div>
          </div>
        </div>
      </aside>

      <main class="flex-1 px-4 py-8 sm:px-8">
        {render_slot(@inner_block)}
      </main>

      <.link navigate={~p"/search"} id="search-hotkey" phx-hook=".SearchHotkey" class="sr-only">
        {dgettext("layouts", "Search films and series")}
      </.link>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SearchHotkey">
        export default {
          mounted() {
            this.onKeydown = (event) => {
              if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== "k") { return }
              event.preventDefault()
              this.el.click()
            }
            window.addEventListener("keydown", this.onKeydown)
          },
          destroyed() {
            window.removeEventListener("keydown", this.onKeydown)
          }
        }
      </script>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :search, :boolean, default: true
  slot :inner_block, required: true

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="font-display text-2xl font-bold text-ink">{render_slot(@inner_block)}</h1>

      <.link
        :if={@search}
        navigate={~p"/search"}
        class="flex items-center gap-2 rounded-full bg-paper-2 px-4 py-2 text-xs font-semibold text-ink-soft hover:text-ink"
      >
        <.icon name="hero-magnifying-glass" class="size-4" />
        {dgettext("layouts", "Search films and series")}
        <kbd class="hidden rounded border border-line px-1 py-0.5 text-[10px] font-bold sm:block">
          {dgettext("layouts", "⌘K")}
        </kbd>
      </.link>
    </div>
    """
  end

  attr :mark, :boolean, default: false
  attr :class, :any, default: nil

  defp wordmark(assigns) do
    ~H"""
    <span class={["flex items-center gap-2 font-display text-lg font-bold text-ink", @class]}>
      <span :if={@mark} class="relative size-5 rounded-md border-[2.5px] border-ink">
        <span class="absolute inset-x-0.5 bottom-0.5 h-1 rounded-sm bg-ink"></span>
      </span>
      {dgettext("layouts", "Track")}
    </span>
    """
  end

  defp toggle_menu do
    JS.toggle_class("-translate-x-full", to: "#side-menu")
    |> JS.toggle_class("hidden", to: "#side-menu-backdrop")
  end

  defp close_menu do
    JS.add_class("-translate-x-full", to: "#side-menu")
    |> JS.add_class("hidden", to: "#side-menu-backdrop")
  end

  defp nav_counts(user) do
    %{
      list: Tracking.status_counts(user).all,
      invites: if(user.admin, do: Accounts.pending_invite_count())
    }
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp nav_group(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5">
      <span class="px-2.5 pb-1 text-[10px] font-extrabold uppercase tracking-widest text-ink-soft">
        {@label}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  attr :count, :integer, default: nil
  slot :inner_block, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      phx-click={close_menu()}
      aria-current={@active && "page"}
      class={[
        "flex items-center gap-2.5 rounded-xl px-2.5 py-1.5 text-sm",
        if(@active,
          do: "font-bold text-ink",
          else: "font-semibold text-ink-soft hover:bg-paper-2 hover:text-ink"
        )
      ]}
    >
      <.icon name={@icon} class={["size-4", if(@active, do: "opacity-100", else: "opacity-80")]} />
      {render_slot(@inner_block)}
      <span :if={@count} class="ml-auto text-[11px] font-bold tabular-nums text-ink-soft">
        {@count}
      </span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
