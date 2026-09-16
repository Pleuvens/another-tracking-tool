defmodule AnotherTrackingTool.Integrations.PlexTest do
  use ExUnit.Case, async: true

  alias AnotherTrackingTool.Integrations.{Event, Plex}

  defp webhook(payload), do: %{"payload" => Jason.encode!(payload)}

  test "source is :plex" do
    assert Plex.source() == :plex
  end

  test "parses a movie scrobble into a watched event" do
    payload = %{
      "event" => "media.scrobble",
      "Account" => %{"id" => 1, "title" => "Alice"},
      "Metadata" => %{
        "type" => "movie",
        "Guid" => [%{"id" => "imdb://tt1160419"}, %{"id" => "tmdb://438631"}]
      }
    }

    assert {:ok, [event]} = Plex.parse(webhook(payload))
    assert %Event{action: :watched, account: %{id: "1", name: "Alice"}} = event
    assert event.media == %{type: :movie, tmdb_id: 438_631}
  end

  test "parses an episode scrobble with the episode's tvdb id and season/episode" do
    payload = %{
      "event" => "media.scrobble",
      "Account" => %{"id" => 2, "title" => "Bob"},
      "Metadata" => %{
        "type" => "episode",
        "grandparentTitle" => "Severance",
        "parentIndex" => 1,
        "index" => 3,
        "Guid" => [%{"id" => "tvdb://9249163"}]
      }
    }

    assert {:ok, [event]} = Plex.parse(webhook(payload))
    assert event.media == %{type: :episode, tvdb_id: 9_249_163, season: 1, episode: 3}
  end

  test "ignores non-scrobble events" do
    payload = %{
      "event" => "media.play",
      "Account" => %{"id" => 1},
      "Metadata" => %{"type" => "movie"}
    }

    assert {:ok, []} = Plex.parse(webhook(payload))
  end

  test "drops a scrobble with no tmdb id" do
    payload = %{
      "event" => "media.scrobble",
      "Account" => %{"id" => 1, "title" => "Alice"},
      "Metadata" => %{"type" => "movie", "Guid" => [%{"id" => "imdb://tt1160419"}]}
    }

    assert {:ok, []} = Plex.parse(webhook(payload))
  end

  test "ignores a request without a payload" do
    assert Plex.parse(%{"other" => "x"}) == :ignore
  end
end
