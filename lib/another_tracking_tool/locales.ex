defmodule AnotherTrackingTool.Locales do
  @moduledoc "Supported UI locales (English base, French translation)."

  @all [:en, :fr]
  @default :en

  def all, do: @all
  def default, do: @default

  def name(:en), do: "English"
  def name(:fr), do: "Français"

  def supported?(locale) when is_atom(locale), do: locale in @all
  def supported?(locale) when is_binary(locale), do: locale in Enum.map(@all, &Atom.to_string/1)
end
