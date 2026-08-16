defmodule AnotherTrackingTool.Tmdb do
  @moduledoc "Client for the TMDB v4 API — the first catalog provider adapter."

  require Logger

  @cinema_kinds AnotherTrackingTool.MediaEnums.cinema_kinds()

  @doc "Multi-search across movies and TV. Results carry `genre_ids`, not full genres."
  def search_multi(query, opts \\ []) do
    get("/search/multi", [query: query, include_adult: false] ++ page_lang(opts))
  end

  @doc "Full details for a movie/TV item, including `external_ids` and (for TV) `seasons`."
  def details(kind, id, opts \\ []) when kind in @cinema_kinds do
    get("/#{path(kind)}/#{id}", [append_to_response: "external_ids"] ++ page_lang(opts))
  end

  @doc "A single TV season with its `episodes` list."
  def season(tv_id, season_number, opts \\ []) do
    get("/tv/#{tv_id}/season/#{season_number}", page_lang(opts))
  end

  @doc "Genre id→name map for a medium."
  def genres(kind, opts \\ []) when kind in @cinema_kinds do
    get("/genre/#{path(kind)}/list", page_lang(opts))
  end

  @doc "Trending movies and TV for the week."
  def trending(opts \\ []) do
    get("/trending/all/week", page_lang(opts))
  end

  @doc "Discover with arbitrary filters, e.g. `with_genres`, `with_original_language`."
  def discover(kind, params, opts \\ []) when kind in @cinema_kinds do
    get("/discover/#{path(kind)}", Enum.to_list(params) ++ page_lang(opts))
  end

  @doc "TMDB configuration, including `images.secure_base_url`."
  def configuration, do: get("/configuration", [])

  defp path(:movie), do: "movie"
  defp path(:tv), do: "tv"

  defp page_lang(opts) do
    [language: Keyword.get(opts, :language, config(:language))]
    |> maybe_put(:page, opts[:page])
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: [{key, value} | params]

  defp get(path, params) do
    case Req.get(req(), url: path, params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("tmdb: #{path} returned #{status}")
        {:error, {:http, status, body}}

      {:error, reason} ->
        Logger.warning("tmdb: #{path} request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp req do
    [
      base_url: config(:base_url),
      auth: {:bearer, config(:access_token)}
    ]
    |> Keyword.merge(config(:req_options) || [])
    |> Req.new()
  end

  defp config(key), do: Application.fetch_env!(:another_tracking_tool, __MODULE__)[key]
end
