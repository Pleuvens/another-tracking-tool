defmodule AnotherTrackingTool.Integrations.Plex do
  @moduledoc """
  Plex webhook connector. Turns a `media.scrobble` payload into a watched
  event; other events are ignored. For episodes Plex's `Guid` array carries
  the show's external ids, with the season and episode in parentIndex/index.
  """

  @behaviour AnotherTrackingTool.Integrations.Connector

  alias AnotherTrackingTool.Integrations.Event

  @impl true
  def source, do: :plex

  @impl true
  def parse(%{"payload" => json}) when is_binary(json) do
    with {:ok, payload} <- Jason.decode(json) do
      {:ok, events(payload)}
    end
  end

  def parse(_raw), do: :ignore

  defp events(%{"event" => "media.scrobble"} = payload) do
    case scrobble_event(payload) do
      nil -> []
      event -> [event]
    end
  end

  defp events(_payload), do: []

  defp scrobble_event(%{"Account" => account, "Metadata" => metadata}) do
    case media(metadata) do
      nil ->
        nil

      media ->
        %Event{
          account: %{id: to_string(account["id"]), name: account["title"]},
          action: :watched,
          media: media,
          occurred_at: DateTime.utc_now()
        }
    end
  end

  defp scrobble_event(_payload), do: nil

  defp media(%{"type" => "movie"} = metadata) do
    case tmdb_id(metadata) do
      nil -> nil
      id -> %{type: :movie, tmdb_id: id}
    end
  end

  defp media(%{"type" => "episode", "parentIndex" => season, "index" => number} = metadata)
       when is_integer(season) and is_integer(number) do
    case tmdb_id(metadata) do
      nil -> nil
      id -> %{type: :episode, tmdb_id: id, season: season, episode: number}
    end
  end

  defp media(_metadata), do: nil

  defp tmdb_id(%{"Guid" => guids}) when is_list(guids) do
    guids
    |> Enum.map(& &1["id"])
    |> Enum.find_value(&parse_tmdb/1)
  end

  defp tmdb_id(_metadata), do: nil

  defp parse_tmdb("tmdb://" <> id) do
    case Integer.parse(id) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp parse_tmdb(_id), do: nil
end
