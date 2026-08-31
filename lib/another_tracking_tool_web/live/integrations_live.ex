defmodule AnotherTrackingToolWeb.IntegrationsLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.{Accounts, Integrations}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  @impl true
  def handle_event("assign", %{"user_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("assign", %{"account_id" => account_id, "user_id" => user_id}, socket) do
    {:ok, _} = Integrations.assign_account(account_id, user_id)
    {:noreply, assign(socket, accounts: Integrations.list_accounts())}
  end

  defp load(socket) do
    users = Accounts.list_users()

    assign(socket,
      settings: Integrations.ensure_settings(:plex),
      accounts: Integrations.list_accounts(),
      user_options: Enum.map(users, &{&1.email, &1.id})
    )
  end

  defp webhook_url(settings), do: url(~p"/integrations/plex/webhook/#{settings.secret}")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:integrations}>
      <h1 class="font-display text-2xl font-bold text-ink">
        {dgettext("integrations", "Plex")}
      </h1>

      <section class="mt-6 rounded-2xl bg-paper-2 p-5">
        <div class="font-display text-lg font-bold text-ink">
          {dgettext("integrations", "Webhook URL")}
        </div>
        <p class="mt-1 text-sm text-ink-soft">
          {dgettext(
            "integrations",
            "Paste this into Plex → Settings → Account → Webhooks. Requires Plex Pass."
          )}
        </p>
        <input
          type="text"
          readonly
          value={webhook_url(@settings)}
          class="mt-3 w-full rounded-full bg-paper-0 px-4 py-2 text-sm text-ink-soft"
        />
      </section>

      <section class="mt-6">
        <div class="font-display text-lg font-bold text-ink">
          {dgettext("integrations", "Plex accounts")}
        </div>

        <p :if={@accounts == []} class="mt-2 text-ink-soft">
          {dgettext(
            "integrations",
            "No Plex accounts yet. Play something in Plex and it will show up here to map."
          )}
        </p>

        <ul class="mt-4 space-y-3">
          <li
            :for={account <- @accounts}
            class="flex items-center justify-between gap-3 rounded-2xl bg-paper-2 p-4"
          >
            <span class="font-display font-bold text-ink">{account.external_name}</span>
            <form id={"assign-#{account.id}"} phx-change="assign" class="shrink-0">
              <input type="hidden" name="account_id" value={account.id} />
              <.input
                type="select"
                name="user_id"
                value={account.user_id}
                options={@user_options}
                prompt={dgettext("integrations", "Unassigned")}
              />
            </form>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end
end
