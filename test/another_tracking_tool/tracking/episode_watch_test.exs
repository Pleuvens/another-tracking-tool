defmodule AnotherTrackingTool.Tracking.EpisodeWatchTest do
  use AnotherTrackingTool.DataCase, async: true

  import AnotherTrackingTool.AccountsFixtures
  import AnotherTrackingTool.CatalogFixtures

  alias AnotherTrackingTool.{Repo, Tracking}
  alias AnotherTrackingTool.Tracking.EpisodeWatch

  setup do
    user = user_fixture()
    show = media_item_fixture(%{kind: :tv})
    season = season_fixture(show, %{season_number: 1})
    %{user: user, show: show, season: season}
  end

  test "mark and unmark toggle a watch and progress", ctx do
    %{user: user, show: show, season: season} = ctx
    e1 = episode_fixture(show, season, %{episode_number: 1})
    e2 = episode_fixture(show, season, %{episode_number: 2})

    Tracking.mark_episode(user, e1)
    assert Tracking.watched_episode_ids(user, show) == MapSet.new([e1.id])
    assert Tracking.episode_progress(user, show) == %{watched: 1, total: 2}

    Tracking.mark_episode(user, e2)
    assert Tracking.episode_progress(user, show) == %{watched: 2, total: 2}

    Tracking.unmark_episode(user, e1)
    assert Tracking.watched_episode_ids(user, show) == MapSet.new([e2.id])
  end

  test "marking is idempotent", ctx do
    %{user: user, show: show, season: season} = ctx
    e1 = episode_fixture(show, season, %{episode_number: 1})
    Tracking.mark_episode(user, e1)
    Tracking.mark_episode(user, e1)
    assert Tracking.episode_progress(user, show).watched == 1
  end

  describe "derived show status" do
    test "one aired episode watched → watching", ctx do
      %{user: user, show: show, season: season} = ctx
      e1 = episode_fixture(show, season, %{episode_number: 1})
      _e2 = episode_fixture(show, season, %{episode_number: 2})

      Tracking.mark_episode(user, e1)
      assert Tracking.get_entry(user, show).status == :watching
    end

    test "all aired episodes watched → completed (unaired excluded)", ctx do
      %{user: user, show: show, season: season} = ctx
      e1 = episode_fixture(show, season, %{episode_number: 1, air_date: ~D[2020-01-01]})
      e2 = episode_fixture(show, season, %{episode_number: 2, air_date: ~D[2020-01-08]})

      _future =
        episode_fixture(show, season, %{
          episode_number: 3,
          air_date: Date.add(Date.utc_today(), 30)
        })

      Tracking.mark_episode(user, e1)
      Tracking.mark_episode(user, e2)
      assert Tracking.get_entry(user, show).status == :completed
    end
  end

  test "mark_season marks every episode in the season", ctx do
    %{user: user, show: show, season: season} = ctx
    episode_fixture(show, season, %{episode_number: 1})
    episode_fixture(show, season, %{episode_number: 2})

    Tracking.mark_season(user, show, 1)
    assert Tracking.season_progress(user, show, 1) == %{watched: 2, total: 2}
    assert Tracking.get_entry(user, show).status == :completed
  end

  test "episode watches appear in recent_activity", ctx do
    %{user: user, show: show, season: season} = ctx
    e1 = episode_fixture(show, season, %{episode_number: 1})
    Tracking.mark_episode(user, e1)

    assert [%{type: :episode, episode: episode, media_item: mi}] = Tracking.recent_activity()
    assert episode.id == e1.id
    assert mi.id == show.id
  end

  test "recent_activity uses episode watched_on for its date", ctx do
    %{user: user, show: show, season: season} = ctx
    e1 = episode_fixture(show, season, %{episode_number: 1})
    Tracking.mark_episode(user, e1)

    watch = Repo.get_by!(EpisodeWatch, episode_id: e1.id)
    Repo.update!(Ecto.Changeset.change(watch, watched_on: ~D[2019-03-03]))

    assert [%{type: :episode, at: at, watched_on: ~D[2019-03-03]}] = Tracking.recent_activity()
    assert DateTime.to_date(at) == ~D[2019-03-03]
  end
end
