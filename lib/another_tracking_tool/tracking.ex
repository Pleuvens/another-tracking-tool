defmodule AnotherTrackingTool.Tracking do
  alias AnotherTrackingTool.Tracking.{
    Broadcast,
    Circle,
    Comments,
    Entries,
    Episodes,
    Imports,
    LastWatched,
    Stats,
    Suggestions
  }

  defdelegate subscribe(media_item), to: Broadcast
  defdelegate subscribe_activity(), to: Broadcast

  defdelegate import_entries(user, entries), to: Imports
  defdelegate import_episode_watches(user, watches), to: Imports

  defdelegate my_list(user, status \\ :all), to: Entries
  defdelegate status_counts(user), to: Entries
  defdelegate get_entry(user, media_item), to: Entries
  defdelegate upsert_entry(user, media_item, attrs), to: Entries
  defdelegate set_status(user, media_item, status), to: Entries
  defdelegate mark_watched(user, media_item, attrs \\ %{}), to: Entries
  defdelegate rate(user, media_item, rating), to: Entries
  defdelegate delete_entry(user, media_item), to: Entries
  defdelegate for_media_item(media_item), to: Entries
  defdelegate circle_rating(media_item), to: Entries

  defdelegate list_comments(media_item), to: Comments
  defdelegate create_comment(user, media_item, body), to: Comments
  defdelegate delete_comment(comment, user), to: Comments

  defdelegate watched_episode_ids(user, media_item), to: Episodes
  defdelegate mark_episode(user, episode, attrs \\ %{}), to: Episodes
  defdelegate unmark_episode(user, episode), to: Episodes
  defdelegate mark_season(user, media_item, season_number), to: Episodes
  defdelegate unmark_season(user, media_item, season_number), to: Episodes
  defdelegate episode_progress(user, media_item), to: Episodes
  defdelegate progress_for(user_id, media_item_ids), to: Episodes
  defdelegate current_seasons(user_id, media_item_ids), to: Episodes
  defdelegate season_progress(user, media_item, season_number), to: Episodes

  defdelegate last_watched(user, period, limit \\ 5), to: LastWatched
  defdelegate circle_latest(user, limit \\ 8), to: Circle
  defdelegate suggestions(user, limit \\ 10), to: Suggestions
  defdelegate watch_totals(user, period), to: Stats
end
