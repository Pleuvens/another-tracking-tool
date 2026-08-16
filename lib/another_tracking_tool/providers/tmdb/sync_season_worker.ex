defmodule AnotherTrackingTool.Providers.Tmdb.SyncSeasonWorker do
  use Oban.Worker, queue: :metadata

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Providers.Tmdb

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_item_id" => id, "season_number" => season_number}}) do
    case Catalog.fetch_media_item(id) do
      {:ok, media_item} -> Tmdb.sync_season(media_item, season_number)
      {:error, :not_found} -> {:cancel, :not_found}
    end
  end
end
