defmodule AnotherTrackingTool.Tracking.Watched do
  import Ecto.Query

  alias AnotherTrackingTool.Tracking.{EpisodeWatch, WatchEntry}

  def films(user_id) do
    from(e in WatchEntry,
      as: :entry,
      join: m in assoc(e, :media_item),
      as: :media_item,
      where: e.user_id == ^user_id and e.status == :completed and m.kind == :movie
    )
  end

  def episodes(user_id) do
    from(w in EpisodeWatch,
      as: :watch,
      join: ep in assoc(w, :episode),
      as: :episode,
      where: w.user_id == ^user_id
    )
  end
end
