defmodule AnotherTrackingToolWeb.Avatars do
  @moduledoc "Deterministic initials and greys for user avatars."

  @greys [
    "#121212",
    "#2e2e2e",
    "#474747",
    "#5f5f5f",
    "#737373"
  ]

  def for_users(users), do: Enum.map(users, &for_user/1)

  def for_user(user), do: %{initial: initial(user), color: color(user.id)}

  def initial(user), do: user.email |> String.first() |> String.upcase()

  def color(id), do: Enum.at(@greys, :erlang.phash2(id, length(@greys)))
end
