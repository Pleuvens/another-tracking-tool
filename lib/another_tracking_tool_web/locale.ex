defmodule AnotherTrackingToolWeb.Locale do
  @moduledoc "Sets the Gettext locale from the current user, falling back to session/default."

  import Plug.Conn

  alias AnotherTrackingTool.Locales

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = resolve(conn.assigns[:current_scope], get_session(conn, "locale"))
    Gettext.put_locale(locale)
    put_session(conn, "locale", locale)
  end

  def on_mount(:default, _params, session, socket) do
    Gettext.put_locale(resolve(socket.assigns[:current_scope], session["locale"]))
    {:cont, socket}
  end

  defp resolve(%{user: %{locale: locale}}, _session) when not is_nil(locale),
    do: Atom.to_string(locale)

  defp resolve(_scope, session_locale) when is_binary(session_locale) do
    if Locales.supported?(session_locale), do: session_locale, else: default()
  end

  defp resolve(_scope, _session), do: default()

  defp default, do: Atom.to_string(Locales.default())
end
