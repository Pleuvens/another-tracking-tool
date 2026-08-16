defmodule AnotherTrackingTool.Catalog.EnrichMediaItemWorker do
  use Oban.Worker, queue: :metadata

  alias AnotherTrackingTool.Catalog

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_item_id" => id}}) do
    case Catalog.fetch_media_item(id) do
      {:ok, media_item} -> Catalog.provider_for(media_item.kind).enrich(media_item)
      {:error, :not_found} -> {:cancel, :not_found}
    end
  end
end
