defmodule AnotherTrackingTool.Tracking.Imports do
  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{Episodes, EpisodeWatch, WatchEntry}

  @insert_chunk 1_000

  def import_entries(%User{id: user_id}, entries) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries
    |> Enum.uniq_by(& &1.media_item_id)
    |> Enum.map(&entry_row(&1, user_id, now))
    |> insert_in_chunks(WatchEntry,
      on_conflict: {:replace, [:status, :rating, :watched_on, :source, :updated_at]},
      conflict_target: [:user_id, :media_item_id]
    )
  end

  def import_episode_watches(%User{id: user_id} = user, watches) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    count =
      watches
      |> Enum.uniq_by(& &1.episode_id)
      |> Enum.map(&episode_watch_row(&1, user_id, now))
      |> insert_in_chunks(EpisodeWatch,
        on_conflict: :nothing,
        conflict_target: [:user_id, :episode_id]
      )

    watches
    |> Enum.map(& &1.media_item_id)
    |> Enum.uniq()
    |> Enum.each(&Episodes.derive_show_status(user, &1))

    count
  end

  defp insert_in_chunks(rows, schema, opts) do
    rows
    |> Enum.chunk_every(@insert_chunk)
    |> Enum.reduce(0, fn chunk, total ->
      {count, _} = Repo.insert_all(schema, chunk, opts)
      total + count
    end)
  end

  defp entry_row(entry, user_id, now) do
    %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      media_item_id: entry.media_item_id,
      status: entry.status,
      rating: entry.rating,
      watched_on: entry.watched_on,
      source: :import,
      inserted_at: now,
      updated_at: now
    }
  end

  defp episode_watch_row(watch, user_id, now) do
    %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      episode_id: watch.episode_id,
      media_item_id: watch.media_item_id,
      watched_on: watch.watched_on,
      inserted_at: now,
      updated_at: now
    }
  end
end
