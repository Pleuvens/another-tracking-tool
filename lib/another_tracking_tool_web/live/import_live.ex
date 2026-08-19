defmodule AnotherTrackingToolWeb.ImportLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Imports
  alias AnotherTrackingTool.Imports.Yamtrack
  alias AnotherTrackingToolWeb.Format

  @coming_soon ["Letterboxd", "MyAnimeList", "Plex", "Trakt"]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Imports.subscribe(socket.assigns.current_scope.user)

    {:ok,
     socket
     |> assign(progress: nil, result: nil, coming_soon: @coming_soon)
     |> allow_upload(:file, accept: ~w(.csv), max_entries: 1, max_file_size: 20_000_000)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("import", _params, socket) do
    user = socket.assigns.current_scope.user

    [binary] =
      consume_uploaded_entries(socket, :file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case Imports.import(user, Yamtrack, binary) do
      {:ok, _job} ->
        {:noreply, assign(socket, progress: %{done: 0, total: nil}, result: nil)}

      _ ->
        {:noreply, put_flash(socket, :error, dgettext("import", "Could not read that file."))}
    end
  end

  @impl true
  def handle_info({:import_progress, progress}, socket) do
    {:noreply, assign(socket, :progress, progress)}
  end

  def handle_info({:import_done, result}, socket) do
    {:noreply, assign(socket, progress: nil, result: result)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:import}>
      <h1 class="font-display text-2xl font-bold text-ink">{dgettext("import", "Import")}</h1>
      <p class="mt-1 text-ink-soft">
        {dgettext("import", "Bring your history over from another tracker.")}
      </p>

      <div class="mt-6 grid gap-4 sm:grid-cols-2">
        <div class="rounded-2xl bg-paper-2 p-5">
          <div class="font-display text-lg font-bold text-ink">Yamtrack</div>
          <p class="mt-1 text-sm text-ink-soft">{dgettext("import", "Upload your CSV export.")}</p>

          <form id="yamtrack-form" phx-change="validate" phx-submit="import" class="mt-4 space-y-3">
            <.live_file_input
              upload={@uploads.file}
              class="text-sm text-ink-soft file:mr-3 file:cursor-pointer file:rounded-full file:border-0 file:bg-ink file:px-4 file:py-2 file:font-extrabold file:text-paper-0 hover:file:opacity-90"
            />
            <.button variant="primary" disabled={@uploads.file.entries == []}>
              {dgettext("import", "Import")}
            </.button>
          </form>

          <div :if={@progress} class="mt-4">
            <div class="h-2 overflow-hidden rounded-full bg-paper-0">
              <div
                class="h-full bg-ink transition-all"
                style={"width: #{Format.percent(@progress.done, @progress.total)}%"}
              >
              </div>
            </div>
            <p class="mt-1 text-xs text-ink-soft">{progress_label(@progress)}</p>
          </div>

          <p :if={@result} class="mt-4 font-display font-bold text-ink">
            {dgettext("import", "%{count} titles rescued from oblivion", count: @result.imported)}
            <span :if={@result.skipped > 0} class="font-sans font-normal text-ink-soft">
              · {dgettext("import", "%{count} skipped", count: @result.skipped)}
            </span>
          </p>
        </div>

        <div
          :for={name <- @coming_soon}
          class="rounded-2xl border border-line p-5 opacity-60"
        >
          <div class="font-display text-lg font-bold text-ink">{name}</div>
          <p class="mt-1 text-sm text-ink-soft">{dgettext("import", "Coming soon")}</p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp progress_label(%{total: total, done: done}) when is_integer(total),
    do: dgettext("import", "%{done} of %{total}", done: done, total: total)

  defp progress_label(_), do: dgettext("import", "Starting…")
end
