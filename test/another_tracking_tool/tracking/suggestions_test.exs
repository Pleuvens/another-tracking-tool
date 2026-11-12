defmodule AnotherTrackingTool.Tracking.SuggestionsTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.Tracking

  setup do
    %{user: user_fixture()}
  end

  defp film(title, genres, attrs \\ %{}) do
    %{kind: :movie, title_fr: title}
    |> Map.merge(attrs)
    |> media_item_fixture()
    |> with_genres(genres)
  end

  test "ranks a title in your most-watched genre first", %{user: user} do
    drama = genre_fixture(%{name_fr: "Drame"})
    horror = genre_fixture(%{name_fr: "Horreur"})

    watched = film("Seen", [drama], %{runtime: 300})
    {:ok, _} = Tracking.mark_watched(user, watched, %{watched_on: Date.utc_today()})

    _in_horror = film("Horror pick", [horror])
    _in_drama = film("Drama pick", [drama])

    assert [first | _] = Tracking.suggestions(user)
    assert first.media_item.title_fr == "Drama pick"
    assert {:top_genre, genre} = first.reason
    assert genre.name_fr == "Drame"
  end

  test "leaves out anything you already track", %{user: user} do
    drama = genre_fixture()
    tracked = film("Tracked", [drama])
    _free = film("Free", [drama])

    {:ok, _} = Tracking.set_status(user, tracked, :not_interested)

    titles = user |> Tracking.suggestions() |> Enum.map(& &1.media_item.title_fr)

    assert titles == ["Free"]
  end

  test "calls a lesser genre frequent rather than top", %{user: user} do
    top = genre_fixture(%{name_fr: "Drame"})
    second = genre_fixture(%{name_fr: "Comédie"})

    big = film("Big", [top], %{runtime: 600})
    small = film("Small", [second], %{runtime: 60})
    {:ok, _} = Tracking.mark_watched(user, big, %{watched_on: Date.utc_today()})
    {:ok, _} = Tracking.mark_watched(user, small, %{watched_on: Date.utc_today()})

    film("Comedy pick", [second])

    assert [%{reason: {:frequent_genre, genre}}] =
             user
             |> Tracking.suggestions()
             |> Enum.filter(&(&1.media_item.title_fr == "Comedy pick"))

    assert genre.name_fr == "Comédie"
  end

  test "falls back to a fan in your circle", %{user: user} do
    unknown = genre_fixture()
    pick = film("Loved by Marie", [unknown])

    marie = user_fixture()
    {:ok, _} = Tracking.upsert_entry(marie, pick, %{status: :completed, rating: 5})

    assert [%{reason: {:circle, fan, 5}}] = Tracking.suggestions(user)
    assert fan.id == marie.id
  end

  test "says new ground when nothing else applies", %{user: user} do
    film("Nobody has seen this", [genre_fixture()])

    assert [%{reason: :new}] = Tracking.suggestions(user)
  end

  test "a circle rating lifts a title above an unloved one", %{user: user} do
    genre = genre_fixture()
    _plain = film("Plain", [genre])
    loved = film("Loved", [genre])

    {:ok, _} = Tracking.upsert_entry(user_fixture(), loved, %{status: :completed, rating: 5})

    assert [first | _] = Tracking.suggestions(user)
    assert first.media_item.title_fr == "Loved"
  end

  test "honours the limit", %{user: user} do
    genre = genre_fixture()
    for n <- 1..3, do: film("Film #{n}", [genre])

    assert length(Tracking.suggestions(user, 2)) == 2
  end

  test "a title with no genres is still suggested", %{user: user} do
    media_item_fixture(%{kind: :movie, title_fr: "Genreless"})

    assert [%{media_item: media_item, reason: :new}] = Tracking.suggestions(user)
    assert media_item.title_fr == "Genreless"
  end
end
