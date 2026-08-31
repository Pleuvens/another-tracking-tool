defmodule AnotherTrackingTool.Integrations do
  @moduledoc "Live sync from external playback sources (Plex today, others later)."

  require Logger

  import Ecto.Query

  alias AnotherTrackingTool.Accounts
  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog
  alias AnotherTrackingTool.Catalog.Episode
  alias AnotherTrackingTool.IntegrationSources
  alias AnotherTrackingTool.Integrations.{Account, Event, IngestWorker, Plex, Settings}
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking

  @sources IntegrationSources.all()
  @connectors %{plex: Plex}

  def sources, do: @sources

  def connector(source) when source in @sources, do: Map.fetch!(@connectors, source)

  @doc "Hands a raw provider request to a background worker so the webhook returns fast."
  def enqueue_ingest(source, raw) when source in @sources do
    %{"source" => Atom.to_string(source), "raw" => raw}
    |> IngestWorker.new()
    |> Oban.insert()
  end

  def ingest_raw(source, raw) when source in @sources do
    case connector(source).parse(raw) do
      {:ok, events} -> ingest(source, events)
      :ignore -> :ok
      {:error, _reason} -> :ok
    end
  end

  def ensure_settings(source) when source in @sources do
    Repo.get_by(Settings, source: source) || create_settings(source)
  end

  def valid_secret?(source, presented) when source in @sources and is_binary(presented) do
    case Repo.get_by(Settings, source: source) do
      %Settings{secret: secret} -> Plug.Crypto.secure_compare(secret, presented)
      nil -> false
    end
  end

  def valid_secret?(_source, _presented), do: false

  defp create_settings(source) do
    {:ok, settings} =
      %Settings{}
      |> Settings.changeset(%{source: source, secret: generate_secret()})
      |> Repo.insert()

    settings
  end

  defp generate_secret, do: 24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

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
      nil ->
        Logger.info("#{source}: event skipped, account not mapped")
        :skipped

      user_id ->
        apply_event(source, Accounts.get_user!(user_id), event)
    end
  end

  defp apply_event(source, user, %Event{action: :watched, media: %{type: :movie} = media} = event) do
    with {:ok, movie} <- Catalog.fetch_and_enrich(:tmdb, media.tmdb_id, :movie) do
      Logger.info("#{source}: recorded movie watch tmdb=#{media.tmdb_id}")
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
      Logger.info(
        "#{source}: recorded episode watch tmdb=#{media.tmdb_id} s#{media.season}e#{media.episode}"
      )

      Tracking.mark_episode(user, episode, %{source: source, watched_on: watched_on(event)})
    else
      nil ->
        Logger.info(
          "#{source}: episode not found tmdb=#{media.tmdb_id} s#{media.season}e#{media.episode}"
        )

        {:error, :episode_not_found}

      error ->
        error
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

  def assign_account(account_id, user_id) do
    map_account(Repo.get!(Account, account_id), Accounts.get_user!(user_id))
  end
end
