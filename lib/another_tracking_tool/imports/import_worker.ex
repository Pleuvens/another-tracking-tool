defmodule AnotherTrackingTool.Imports.ImportWorker do
  use Oban.Worker, queue: :imports

  alias AnotherTrackingTool.{Accounts, Catalog, Coerce, Imports, Tracking, WatchStatuses}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "rows" => rows}}) do
    user = Accounts.get_user!(user_id)
    media_items = fetch_media_items(user_id, rows)

    entries =
      for row <- rows, media_item = media_items[row["tmdb_id"]], do: entry(media_item, row)

    imported = Tracking.import_entries(user, entries)

    Imports.broadcast(
      user_id,
      {:import_done, %{imported: imported, skipped: length(rows) - imported, total: length(rows)}}
    )

    :ok
  end

  defp fetch_media_items(user_id, rows) do
    ids = rows |> Enum.map(& &1["tmdb_id"]) |> Enum.uniq()
    known = Catalog.enriched_by_tmdb(ids, :movie)
    to_fetch = Enum.reject(unique_rows(rows), &Map.has_key?(known, &1["tmdb_id"]))
    total = length(to_fetch)

    to_fetch
    |> Enum.with_index(1)
    |> Enum.reduce(known, fn {row, done}, acc ->
      acc =
        case Catalog.fetch_and_enrich(:tmdb, row["tmdb_id"], :movie, %{title_fr: row["title"]}) do
          {:ok, media_item} -> Map.put(acc, row["tmdb_id"], media_item)
          _ -> acc
        end

      Imports.broadcast(user_id, {:import_progress, %{done: done, total: total}})
      acc
    end)
  end

  defp unique_rows(rows), do: Enum.uniq_by(rows, & &1["tmdb_id"])

  defp entry(media_item, row) do
    %{
      media_item_id: media_item.id,
      status: WatchStatuses.from_string(row["status"]),
      rating: row["rating"],
      watched_on: Coerce.date(row["watched_on"])
    }
  end
end
