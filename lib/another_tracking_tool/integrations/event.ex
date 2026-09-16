defmodule AnotherTrackingTool.Integrations.Event do
  @moduledoc """
  A normalized playback event from any integration source.

  `account` is the provider's user identity (`%{id, name}`); `media` carries
  external ids for matching: `%{type: :movie, tmdb_id}` or
  `%{type: :episode, tvdb_id, season, episode}`.
  """

  @enforce_keys [:account, :action, :media, :occurred_at]
  defstruct [:account, :action, :media, :rating, :occurred_at]
end
