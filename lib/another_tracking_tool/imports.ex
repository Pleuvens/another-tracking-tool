defmodule AnotherTrackingTool.Imports do
  @moduledoc "Backfill imports from external trackers."

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Imports.{ImportWorker, Yamtrack}

  @pubsub AnotherTrackingTool.PubSub
  @sources [Yamtrack]

  def sources, do: @sources

  def subscribe(%User{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  def import(%User{} = user, source, binary) when source in @sources do
    with {:ok, rows} <- source.parse(binary) do
      %{user_id: user.id, rows: rows} |> ImportWorker.new() |> Oban.insert()
    end
  end

  def broadcast(user_id, message), do: Phoenix.PubSub.broadcast(@pubsub, topic(user_id), message)

  defp topic(user_id), do: "imports:#{user_id}"
end
