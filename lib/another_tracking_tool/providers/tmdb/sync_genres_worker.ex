defmodule AnotherTrackingTool.Providers.Tmdb.SyncGenresWorker do
  use Oban.Worker, queue: :metadata

  alias AnotherTrackingTool.Providers.Tmdb

  @impl Oban.Worker
  def perform(%Oban.Job{}), do: Tmdb.sync_genres()
end
