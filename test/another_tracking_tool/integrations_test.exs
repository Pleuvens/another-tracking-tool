defmodule AnotherTrackingTool.IntegrationsTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Integrations
  alias AnotherTrackingTool.Integrations.{Account, Event}
  alias AnotherTrackingTool.Tracking
  alias AnotherTrackingTool.Tracking.{EpisodeWatch, WatchEntry}

  describe "record_account/3" do
    test "creates an unmapped account on first sight" do
      {:ok, account} = Integrations.record_account(:plex, "42", "Alice")

      assert account.source == :plex
      assert account.external_id == "42"
      assert account.external_name == "Alice"
      assert is_nil(account.user_id)
    end

    test "is idempotent per (source, external_id) and refreshes the name" do
      {:ok, first} = Integrations.record_account(:plex, "42", "Alice")
      {:ok, second} = Integrations.record_account(:plex, "42", "Alice Renamed")

      assert first.id == second.id
      assert second.external_name == "Alice Renamed"
      assert Repo.aggregate(Account, :count) == 1
    end
  end

  describe "mapped_user_id/2" do
    test "is nil while the account is unmapped" do
      {:ok, _} = Integrations.record_account(:plex, "42", "Alice")
      assert Integrations.mapped_user_id(:plex, "42") == nil
    end

    test "is the user id once mapped" do
      user = user_fixture()
      {:ok, account} = Integrations.record_account(:plex, "42", "Alice")
      {:ok, _} = Integrations.map_account(account, user)

      assert Integrations.mapped_user_id(:plex, "42") == user.id
    end

    test "is nil for an unknown account" do
      assert Integrations.mapped_user_id(:plex, "nope") == nil
    end
  end

  describe "list_accounts/0" do
    test "lists accounts with the mapped user preloaded" do
      user = user_fixture()
      {:ok, account} = Integrations.record_account(:plex, "42", "Alice")
      {:ok, _} = Integrations.map_account(account, user)

      assert [listed] = Integrations.list_accounts()
      assert listed.user.id == user.id
    end
  end

  describe "ensure_settings/1 and valid_secret?/2" do
    test "creates a settings row with a secret, idempotently" do
      settings = Integrations.ensure_settings(:plex)
      assert settings.secret

      assert Integrations.ensure_settings(:plex).id == settings.id
    end

    test "valid_secret? accepts the stored secret and rejects others" do
      settings = Integrations.ensure_settings(:plex)

      assert Integrations.valid_secret?(:plex, settings.secret)
      refute Integrations.valid_secret?(:plex, "wrong")
    end

    test "valid_secret? is false when no settings exist" do
      refute Integrations.valid_secret?(:plex, "anything")
    end
  end

  describe "ingest/2" do
    test "queues the account and writes nothing for an unmapped account" do
      media_item_fixture(%{kind: :movie, source_id: 603, details_synced_at: synced()})

      Integrations.ingest(:plex, [watched_event("7", %{type: :movie, tmdb_id: 603})])

      assert Repo.aggregate(WatchEntry, :count) == 0
      assert %Account{user_id: nil} = Integrations.get_account_by_external_id(:plex, "7")
    end

    test "records a movie watch for the mapped user" do
      user = mapped_user("7")
      movie = media_item_fixture(%{kind: :movie, source_id: 603, details_synced_at: synced()})

      Integrations.ingest(:plex, [watched_event("7", %{type: :movie, tmdb_id: 603})])

      entry = Tracking.get_entry(user, movie)
      assert entry.status == :completed
      assert entry.source == :plex
      assert entry.watched_on == ~D[2024-03-03]
    end

    test "records an episode watch for the mapped user" do
      user = mapped_user("7")
      show = media_item_fixture(%{kind: :tv, source_id: 1399, details_synced_at: synced()})
      season = season_fixture(show, %{season_number: 1})
      episode = episode_fixture(show, season, %{episode_number: 3})

      event = watched_event("7", %{type: :episode, tmdb_id: 1399, season: 1, episode: 3})
      Integrations.ingest(:plex, [event])

      watch = Repo.get_by!(EpisodeWatch, user_id: user.id, episode_id: episode.id)
      assert watch.source == :plex
      assert watch.watched_on == ~D[2024-03-03]
    end
  end

  defp mapped_user(external_id) do
    user = user_fixture()
    {:ok, account} = Integrations.record_account(:plex, external_id, "Alice")
    {:ok, _} = Integrations.map_account(account, user)
    user
  end

  defp watched_event(account_id, media) do
    %Event{
      account: %{id: account_id, name: "Alice"},
      action: :watched,
      media: media,
      occurred_at: ~U[2024-03-03 20:00:00Z]
    }
  end

  defp synced, do: DateTime.utc_now(:second)
end
