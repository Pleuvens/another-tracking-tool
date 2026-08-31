defmodule AnotherTrackingTool.Accounts.UserNotifier do
  import Swoosh.Email
  use Gettext, backend: AnotherTrackingToolWeb.Gettext

  alias AnotherTrackingTool.Mailer
  alias AnotherTrackingTool.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Application.get_env(:another_tracking_tool, :mailer_from))
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver_instructions(
      user,
      url,
      dgettext("accounts", "Update email instructions"),
      dgettext("accounts", "You can change your email by visiting the URL below:"),
      dgettext("accounts", "If you didn't request this change, please ignore this.")
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver_instructions(
      user,
      url,
      dgettext("accounts", "Log in instructions"),
      dgettext("accounts", "You can log into your account by visiting the URL below:"),
      dgettext("accounts", "If you didn't request this email, please ignore this.")
    )
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver_instructions(
      user,
      url,
      dgettext("accounts", "Confirmation instructions"),
      dgettext("accounts", "You can confirm your account by visiting the URL below:"),
      dgettext("accounts", "If you didn't create an account with us, please ignore this.")
    )
  end

  # Emails render in the recipient's locale, not the caller's request locale.
  defp deliver_instructions(%User{} = user, url, subject, action_line, disclaimer) do
    Gettext.with_locale(AnotherTrackingToolWeb.Gettext, to_string(user.locale), fn ->
      body = """

      ==============================

      #{dgettext("accounts", "Hi %{email},", email: user.email)}

      #{action_line}

      #{url}

      #{disclaimer}

      ==============================
      """

      deliver(user.email, subject, body)
    end)
  end
end
