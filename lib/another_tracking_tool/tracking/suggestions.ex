defmodule AnotherTrackingTool.Tracking.Suggestions do
  import Ecto.Query

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.Catalog.MediaItem
  alias AnotherTrackingTool.Repo
  alias AnotherTrackingTool.Tracking.{WatchEntry, Watched}

  @pool 200
  @top_genre_points 8
  @frequent_genre_rank 4
  @circle_rating 4

  def suggestions(%User{} = user, limit \\ 10) do
    ranks = genre_ranks(user)
    candidates = candidate_pool(user)
    fans = circle_fans(user, Enum.map(candidates, & &1.id))

    candidates
    |> Enum.map(&weigh(&1, ranks, Map.get(fans, &1.id, [])))
    |> Enum.sort_by(&{-&1.score, MediaItem.display_title(&1.media_item)})
    |> Enum.take(limit)
    |> Enum.map(&Map.take(&1, [:media_item, :reason]))
  end

  defp weigh(media_item, ranks, fans) do
    matched = matched_genres(media_item, ranks)

    %{
      media_item: media_item,
      score: genre_points(matched, ranks) + fan_points(fans),
      reason: reason(matched, ranks, fans)
    }
  end

  defp matched_genres(media_item, ranks) do
    media_item.tmdb_genres
    |> Enum.filter(&Map.has_key?(ranks, &1.id))
    |> Enum.sort_by(&Map.fetch!(ranks, &1.id))
  end

  defp genre_points(matched, ranks) do
    Enum.reduce(matched, 0, fn genre, points ->
      points + max(0, @top_genre_points - Map.fetch!(ranks, genre.id))
    end)
  end

  defp fan_points(fans), do: Enum.reduce(fans, 0, &(&2 + &1.rating))

  defp reason([genre | _], ranks, fans) do
    case Map.fetch!(ranks, genre.id) do
      0 -> {:top_genre, genre}
      rank when rank < @frequent_genre_rank -> {:frequent_genre, genre}
      _rank -> fan_reason(fans)
    end
  end

  defp reason([], _ranks, fans), do: fan_reason(fans)

  defp fan_reason([fan | _]), do: {:circle, fan.user, fan.rating}
  defp fan_reason([]), do: :new

  defp genre_ranks(%User{} = user) do
    user
    |> genre_minutes()
    |> Enum.sort_by(fn {_genre_id, minutes} -> -minutes end)
    |> Enum.with_index()
    |> Map.new(fn {{genre_id, _minutes}, rank} -> {genre_id, rank} end)
  end

  defp genre_minutes(%User{id: user_id}) do
    films =
      user_id
      |> Watched.films()
      |> join(:inner, [media_item: m], g in assoc(m, :tmdb_genres), as: :genre)
      |> group_by([genre: g], g.id)
      |> select([media_item: m, genre: g], {g.id, coalesce(sum(m.runtime), 0)})

    episodes =
      user_id
      |> Watched.episodes()
      |> join(:inner, [watch: w], m in assoc(w, :media_item), as: :media_item)
      |> join(:inner, [media_item: m], g in assoc(m, :tmdb_genres), as: :genre)
      |> group_by([genre: g], g.id)
      |> select([episode: ep, genre: g], {g.id, coalesce(sum(ep.runtime), 0)})

    Map.merge(
      films |> Repo.all() |> Map.new(),
      episodes |> Repo.all() |> Map.new(),
      fn _genre_id, from_films, from_episodes -> from_films + from_episodes end
    )
  end

  defp candidate_pool(%User{id: user_id}) do
    from(m in MediaItem,
      left_join: e in WatchEntry,
      on: e.media_item_id == m.id and e.user_id == ^user_id,
      where: is_nil(e.id),
      order_by: [desc_nulls_last: m.tmdb_popularity, asc: m.id],
      limit: @pool,
      preload: [:tmdb_genres]
    )
    |> Repo.all()
  end

  defp circle_fans(_user, []), do: %{}

  defp circle_fans(%User{id: user_id}, media_item_ids) do
    from(e in WatchEntry,
      where:
        e.media_item_id in ^media_item_ids and e.user_id != ^user_id and
          e.rating >= @circle_rating,
      order_by: [desc: e.rating],
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.media_item_id)
  end
end
