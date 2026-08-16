defmodule AnotherTrackingTool.Providers.Tmdb.SeedWorker do
  use Oban.Worker, queue: :sync

  import Ecto.Query

  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.MediaEnums
  alias AnotherTrackingTool.Providers.Tmdb
  alias AnotherTrackingTool.Repo

  @budget 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    page = args["page"] || 1
    remaining = args["remaining"] || @budget

    with {:ok, attrs_list} <- fetch(args, page) do
      fresh = reject_enriched(attrs_list)
      seeded = Enum.take(fresh, remaining)
      Enum.each(seeded, &seed_one/1)
      maybe_enqueue_next(args, page, remaining - length(seeded), fresh)
      :ok
    end
  end

  defp fetch(%{"source" => "trending"}, page), do: Tmdb.trending(page: page)

  defp fetch(%{"source" => "discover", "kind" => kind, "params" => params}, page),
    do: Tmdb.discover(MediaEnums.to_existing_cinema_kind(kind), params, page: page)

  defp reject_enriched(attrs_list) do
    ids = Enum.map(attrs_list, & &1.source_id)

    enriched =
      from(m in MediaItem,
        where: m.tmdb_id in ^ids and not is_nil(m.details_synced_at),
        select: {m.kind, m.tmdb_id}
      )
      |> Repo.all()
      |> MapSet.new()

    Enum.reject(attrs_list, &MapSet.member?(enriched, {&1.kind, &1.source_id}))
  end

  defp seed_one(attrs) do
    with {:ok, media_item} <- Catalog.upsert_media_item(attrs) do
      Catalog.ensure_details(media_item)
    end
  end

  defp maybe_enqueue_next(_args, _page, remaining, _fresh) when remaining <= 0, do: :ok
  defp maybe_enqueue_next(_args, _page, _remaining, []), do: :ok

  defp maybe_enqueue_next(args, page, remaining, _fresh),
    do:
      args |> Map.merge(%{"page" => page + 1, "remaining" => remaining}) |> new() |> Oban.insert()
end
