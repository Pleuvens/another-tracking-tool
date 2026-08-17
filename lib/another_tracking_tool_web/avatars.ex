defmodule AnotherTrackingToolWeb.Avatars do
  @moduledoc "Deterministic initials and colors for user avatars."

  @colors [
    "oklch(70% 0.1 250)",
    "oklch(65% 0.09 25)",
    "oklch(65% 0.08 145)",
    "oklch(70% 0.09 85)",
    "oklch(65% 0.1 310)"
  ]

  def for_users(users), do: Enum.map(users, &for_user/1)

  def for_user(user), do: %{initial: initial(user), color: color(user.id)}

  def initial(user), do: user.email |> String.first() |> String.upcase()

  def color(id), do: Enum.at(@colors, :erlang.phash2(id, length(@colors)))
end
