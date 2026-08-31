defmodule AnotherTrackingTool.Integrations.IngestWorker do
  use Oban.Worker, queue: :sync

  alias AnotherTrackingTool.{IntegrationSources, Integrations}

  @impl true
  def perform(%Oban.Job{args: %{"source" => source, "raw" => raw}}) do
    case IntegrationSources.from_string(source) do
      nil -> :ok
      source -> Integrations.ingest_raw(source, raw)
    end
  end
end
