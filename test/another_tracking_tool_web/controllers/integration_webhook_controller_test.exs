defmodule AnotherTrackingToolWeb.IntegrationWebhookControllerTest do
  use AnotherTrackingToolWeb.ConnCase, async: true
  use Oban.Testing, repo: AnotherTrackingTool.Repo

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Integrations
  alias AnotherTrackingTool.Integrations.IngestWorker
  alias AnotherTrackingTool.Tracking

  defp movie_payload do
    Jason.encode!(%{
      "event" => "media.scrobble",
      "Account" => %{"id" => 1, "title" => "Alice"},
      "Metadata" => %{"type" => "movie", "Guid" => [%{"id" => "tmdb://438631"}]}
    })
  end

  test "accepts a valid webhook and enqueues ingestion", %{conn: conn} do
    secret = Integrations.ensure_settings(:plex).secret
    payload = movie_payload()

    conn = post(conn, ~p"/integrations/plex/webhook/#{secret}", %{"payload" => payload})

    assert response(conn, 200)

    assert_enqueued(
      worker: IngestWorker,
      args: %{"source" => "plex", "raw" => %{"payload" => payload}}
    )
  end

  test "rejects a bad secret", %{conn: conn} do
    Integrations.ensure_settings(:plex)

    conn = post(conn, ~p"/integrations/plex/webhook/wrong", %{"payload" => movie_payload()})

    assert response(conn, 401)
    refute_enqueued(worker: IngestWorker)
  end

  test "returns 404 for an unknown source", %{conn: conn} do
    conn = post(conn, ~p"/integrations/unknown/webhook/x", %{"payload" => "{}"})

    assert response(conn, 404)
  end

  test "the enqueued job records the watch end to end", %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Integrations.record_account(:plex, "1", "Alice")
    {:ok, _} = Integrations.map_account(account, user)
    movie = media_item_fixture(%{kind: :movie, source_id: 438_631, details_synced_at: synced()})
    secret = Integrations.ensure_settings(:plex).secret

    post(conn, ~p"/integrations/plex/webhook/#{secret}", %{"payload" => movie_payload()})

    assert :ok =
             perform_job(IngestWorker, %{
               "source" => "plex",
               "raw" => %{"payload" => movie_payload()}
             })

    assert Tracking.get_entry(user, movie).source == :plex
  end

  defp synced, do: DateTime.utc_now(:second)
end
