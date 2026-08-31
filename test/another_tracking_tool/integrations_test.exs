defmodule AnotherTrackingTool.IntegrationsTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures

  alias AnotherTrackingTool.Integrations
  alias AnotherTrackingTool.Integrations.Account

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
end
