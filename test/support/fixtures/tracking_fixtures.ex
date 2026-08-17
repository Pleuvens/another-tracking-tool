defmodule AnotherTrackingTool.TrackingFixtures do
  @moduledoc "Persisted tracking records for tests."

  alias AnotherTrackingTool.Tracking

  def watch_entry_fixture(user, media_item, attrs \\ %{}) do
    {:ok, entry} =
      Tracking.upsert_entry(user, media_item, Enum.into(attrs, %{status: :completed}))

    entry
  end

  def comment_fixture(user, media_item, body \\ "Nice one") do
    {:ok, comment} = Tracking.create_comment(user, media_item, body)
    comment
  end
end
