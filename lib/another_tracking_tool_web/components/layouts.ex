defmodule AnotherTrackingToolWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AnotherTrackingToolWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom, default: nil, doc: "the active sidebar nav item"

  slot :inner_block, required: true

  def app(%{current_scope: nil} = assigns) do
    ~H"""
    <header class="border-b border-line">
      <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
        <a href="/" class="font-display text-lg font-bold text-ink">cercle</a>
        <nav class="flex items-center gap-5 text-sm font-bold text-ink-soft">
          <.link navigate={~p"/users/register"} class="hover:text-ink">
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
    ~H"""
    <div class="md:flex md:min-h-screen">
      <aside class="border-b border-line md:w-56 md:shrink-0 md:border-r md:border-b-0">
        <div class="flex flex-wrap items-center gap-2 p-4 md:h-full md:flex-col md:items-stretch md:gap-8">
          <div class="font-display text-lg font-bold text-ink">cercle</div>
          <nav class="flex flex-1 flex-wrap gap-1 md:flex-col md:flex-none">
            <.sidebar_link navigate={~p"/feed"} active={@active == :feed}>
              {dgettext("layouts", "Home")}
            </.sidebar_link>
            <.sidebar_link navigate={~p"/search"} active={@active == :search}>
              {dgettext("layouts", "Discover")}
            </.sidebar_link>
            <.sidebar_link navigate={~p"/watchlist"} active={@active == :watchlist}>
              {dgettext("layouts", "Watchlist")}
            </.sidebar_link>
            <.sidebar_link navigate={~p"/import"} active={@active == :import}>
              {dgettext("layouts", "Import")}
            </.sidebar_link>
            <.sidebar_link navigate={~p"/users/settings"} active={@active == :profile}>
              {dgettext("layouts", "Profile")}
            </.sidebar_link>
          </nav>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="rounded-xl px-3 py-2 text-sm font-bold text-ink-soft hover:text-ink md:mt-auto"
          >
            {dgettext("layouts", "Log out")}
          </.link>
        </div>
      </aside>

      <main class="flex-1 px-4 py-8 sm:px-8">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "rounded-xl px-3 py-2 text-sm font-bold",
        if(@active, do: "bg-paper-2 text-ink", else: "text-ink-soft hover:text-ink")
      ]}
    >
      {render_slot(@inner_block)}
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
