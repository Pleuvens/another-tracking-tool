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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-line">
      <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
        <a href="/" class="font-display text-lg font-bold text-ink">another tracking tool</a>
        <nav class="flex items-center gap-5 text-sm font-bold text-ink-soft">
          <%= if @current_scope do %>
            <span class="hidden text-ink-soft sm:inline">{@current_scope.user.email}</span>
            <.link navigate={~p"/users/settings"} class="hover:text-ink">
              {gettext("Settings")}
            </.link>
            <.link href={~p"/users/log-out"} method="delete" class="hover:text-ink">
              {gettext("Log out")}
            </.link>
          <% else %>
            <.link navigate={~p"/users/register"} class="hover:text-ink">
              {gettext("Register")}
            </.link>
            <.link navigate={~p"/users/log-in"} class="hover:text-ink">
              {gettext("Log in")}
            </.link>
          <% end %>
        </nav>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
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
