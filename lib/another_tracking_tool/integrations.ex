defmodule AnotherTrackingTool.Integrations do
  @moduledoc "Live sync from external playback sources (Plex today, others later)."

  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.IntegrationSources
  alias AnotherTrackingTool.Integrations.Account
  alias AnotherTrackingTool.Repo

  @sources IntegrationSources.all()

  def sources, do: @sources

  def record_account(source, external_id, external_name)
      when source in @sources and is_binary(external_id) do
    %Account{}
    |> Account.changeset(%{
      source: source,
      external_id: external_id,
      external_name: external_name
    })
    |> Repo.insert(
      on_conflict: {:replace, [:external_name, :updated_at]},
      conflict_target: [:source, :external_id],
      returning: true
    )
  end

  def get_account_by_external_id(source, external_id),
    do: Repo.get_by(Account, source: source, external_id: external_id)

  def mapped_user_id(source, external_id) do
    case get_account_by_external_id(source, external_id) do
      %Account{user_id: user_id} -> user_id
      nil -> nil
    end
  end

  def list_accounts do
    Repo.all(from a in Account, order_by: [asc: a.source, asc: a.external_name], preload: [:user])
  end

  def map_account(%Account{} = account, %User{} = user),
    do: account |> Account.changeset(%{user_id: user.id}) |> Repo.update()
end
