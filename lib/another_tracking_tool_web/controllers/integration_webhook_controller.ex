defmodule AnotherTrackingToolWeb.IntegrationWebhookController do
  use AnotherTrackingToolWeb, :controller

  alias AnotherTrackingTool.{IntegrationSources, Integrations}

  def create(conn, %{"source" => source_param, "secret" => secret} = params) do
    with source when not is_nil(source) <- IntegrationSources.from_string(source_param),
         true <- Integrations.valid_secret?(source, secret) do
      Integrations.enqueue_ingest(source, Map.take(params, ["payload"]))
      send_resp(conn, :ok, "")
    else
      nil -> send_resp(conn, :not_found, "")
      false -> send_resp(conn, :unauthorized, "")
    end
  end
end
