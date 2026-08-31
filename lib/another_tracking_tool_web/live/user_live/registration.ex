defmodule AnotherTrackingToolWeb.UserLive.Registration do
  use AnotherTrackingToolWeb, :live_view

  alias AnotherTrackingTool.Accounts
  alias AnotherTrackingTool.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            {heading(@mode)}
            <:subtitle>
              {dgettext("accounts", "Already registered?")}
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                {dgettext("accounts", "Log in")}
              </.link>
              {dgettext("accounts", "to your account now.")}
            </:subtitle>
          </.header>
        </div>

        <p :if={@mode == :no_invite} class="mt-4 text-center text-ink-soft">
          {dgettext("accounts", "You need an invitation to join. Ask an admin for an invite link.")}
        </p>

        <.form
          :if={@mode != :no_invite}
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
        >
          <.input
            field={@form[:email]}
            type="email"
            label={dgettext("accounts", "Email")}
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />

          <.button
            phx-disable-with={dgettext("accounts", "Creating account…")}
            class="btn btn-primary w-full"
          >
            {dgettext("accounts", "Create an account")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: AnotherTrackingToolWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    {mode, invite} = registration_mode(params)
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, socket |> assign(mode: mode, invite: invite) |> assign_form(changeset),
     temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case register(socket.assigns, user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

        {:noreply,
         socket
         |> put_flash(
           :info,
           dgettext(
             "accounts",
             "An email was sent to %{email}, please access it to confirm your account.",
             email: user.email
           )
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :invalid_invite} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("accounts", "That invitation is no longer valid."))
         |> assign(mode: :no_invite, invite: nil)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp register(%{mode: :bootstrap}, params), do: Accounts.register_first_admin(params)

  defp register(%{mode: :invited, invite: invite}, params),
    do: Accounts.register_user_with_invite(invite.code, params)

  defp registration_mode(params) do
    cond do
      Accounts.first_user?() -> {:bootstrap, nil}
      invite = redeemable_invite(params) -> {:invited, invite}
      true -> {:no_invite, nil}
    end
  end

  defp redeemable_invite(%{"code" => code}) when is_binary(code),
    do: Accounts.get_redeemable_invite(code)

  defp redeemable_invite(_), do: nil

  defp heading(:bootstrap), do: dgettext("accounts", "Create the first account")
  defp heading(:invited), do: dgettext("accounts", "You've been invited")
  defp heading(:no_invite), do: dgettext("accounts", "Invitation required")

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
