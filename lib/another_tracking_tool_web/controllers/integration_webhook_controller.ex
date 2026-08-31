defmodule AnotherTrackingToolWeb.IntegrationWebhookController do
  use AnotherTrackingToolWeb, :controller

  require Logger

  alias AnotherTrackingTool.{IntegrationSources, Integrations}

  def create(conn, %{"source" => source_param, "secret" => secret} = params) do
    with source when not is_nil(source) <- IntegrationSources.from_string(source_param),
         true <- Integrations.valid_secret?(source, secret) do
      Logger.info("integration webhook accepted: source=#{source}")
      Integrations.enqueue_ingest(source, %{"payload" => payload_body(params)})
      send_resp(conn, :ok, "")
    else
      nil ->
        Logger.warning("integration webhook rejected: unknown source #{source_param}")
        send_resp(conn, :not_found, "")

      false ->
        Logger.warning("integration webhook rejected: invalid secret for source #{source_param}")
        send_resp(conn, :unauthorized, "")
    end
  end

  # Plex posts the payload as a multipart part typed application/json, so Plug
  # hands it to us as an upload rather than a string; read it here while the
  # temp file still exists (it is gone by the time the job runs).
  defp payload_body(%{"payload" => %Plug.Upload{path: path}}), do: File.read!(path)
  defp payload_body(%{"payload" => payload}) when is_binary(payload), do: payload
  defp payload_body(_params), do: nil
end
