defmodule AnotherTrackingToolWeb.InviteLive do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Accounts
  alias AnotherTrackingTool.Accounts.Invite

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, invites: Accounts.list_invites())}
  end

  @impl true
  def handle_event("create_invite", _params, socket) do
    {:ok, _invite} = Accounts.create_invite(socket.assigns.current_scope.user)
    {:noreply, assign(socket, invites: Accounts.list_invites())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:invites}>
      <div class="flex items-center justify-between">
        <h1 class="font-display text-2xl font-bold text-ink">
          {dgettext("invites", "Invites")}
        </h1>
        <.button variant="primary" phx-click="create_invite">
          {dgettext("invites", "Create invite link")}
        </.button>
      </div>

      <p :if={@invites == []} class="mt-6 text-ink-soft">
        {dgettext("invites", "No invites yet. Create one to bring someone in.")}
      </p>

      <ul class="mt-6 space-y-4">
        <.invite_row :for={invite <- @invites} invite={invite} />
      </ul>
    </Layouts.app>
    """
  end

  attr :invite, Invite, required: true

  defp invite_row(assigns) do
    assigns = assign(assigns, :status, Invite.status(assigns.invite))

    ~H"""
    <li class="rounded-2xl bg-paper-2 p-4">
      <div class="flex items-center justify-between gap-3">
        <input
          type="text"
          readonly
          value={invite_url(@invite)}
          class="w-full rounded-full bg-paper-0 px-4 py-2 text-sm text-ink-soft"
        />
        <span class="shrink-0 rounded-full bg-paper-0 px-3 py-1 text-xs font-bold text-ink-soft">
          {status_label(@status)}
        </span>
      </div>
      <p :if={@status == :pending} class="mt-2 text-xs text-ink-soft">
        {dgettext("invites", "Expires %{date}",
          date: Calendar.strftime(@invite.expires_at, "%Y-%m-%d")
        )}
      </p>
    </li>
    """
  end

  defp invite_url(invite), do: url(~p"/users/register/#{invite.code}")

  defp status_label(:pending), do: dgettext("invites", "Pending")
  defp status_label(:used), do: dgettext("invites", "Used")
  defp status_label(:expired), do: dgettext("invites", "Expired")
end
