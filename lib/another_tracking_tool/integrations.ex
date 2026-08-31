defmodule AnotherTrackingTool.Integrations do
  @moduledoc "Live sync from external playback sources (Plex today, others later)."

  import Ecto.Query

  alias AnotherTrackingTool.Accounts
  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.Episode
  alias AnotherTrackingTool.IntegrationSources
  alias AnotherTrackingTool.Integrations.{Account, Event}
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking

  @sources IntegrationSources.all()

  def sources, do: @sources

  @doc """
  Applies normalized events from a source: records each provider account,
  then writes a watch for the mapped app user. Events for unmapped accounts
  are queued (via the recorded account) and otherwise skipped.
  """
  def ingest(source, events) when source in @sources do
    Enum.each(events, &ingest_event(source, &1))
  end

  defp ingest_event(source, %Event{account: account} = event) do
    record_account(source, account.id, account.name)

    case mapped_user_id(source, account.id) do
      nil -> :skipped
      user_id -> apply_event(source, Accounts.get_user!(user_id), event)
    end
  end

  defp apply_event(source, user, %Event{action: :watched, media: %{type: :movie} = media} = event) do
    with {:ok, movie} <- Catalog.fetch_and_enrich(:tmdb, media.tmdb_id, :movie) do
      Tracking.mark_watched(user, movie, %{source: source, watched_on: watched_on(event)})
    end
  end

  defp apply_event(
         source,
         user,
         %Event{action: :watched, media: %{type: :episode} = media} = event
       ) do
    with {:ok, show} <- Catalog.fetch_tv_with_episodes(media.tmdb_id),
         %Episode{} = episode <- Catalog.get_episode(show, media.season, media.episode) do
      Tracking.mark_episode(user, episode, %{source: source, watched_on: watched_on(event)})
    else
      nil -> {:error, :episode_not_found}
      error -> error
    end
  end

  defp apply_event(_source, _user, _event), do: :ignored

  defp watched_on(%Event{occurred_at: %DateTime{} = at}), do: DateTime.to_date(at)
  defp watched_on(_event), do: Date.utc_today()

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
