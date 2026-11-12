defmodule AnotherTrackingTool.Tracking.Broadcast do
  alias AnotherTrackingTool.Catalog.MediaItem

  @pubsub AnotherTrackingTool.PubSub
  @activity_topic "activity"

  def subscribe(%MediaItem{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  def subscribe_activity, do: Phoenix.PubSub.subscribe(@pubsub, @activity_topic)

  def media(media_item_id, message),
    do: Phoenix.PubSub.broadcast(@pubsub, topic(media_item_id), message)

  def activity(user_id, subject),
    do:
      Phoenix.PubSub.broadcast(
        @pubsub,
        @activity_topic,
        {:activity, %{user_id: user_id, subject: subject}}
      )

  defp topic(media_item_id), do: "media:#{media_item_id}"
end
