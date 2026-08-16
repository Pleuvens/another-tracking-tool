defmodule AnotherTrackingTool.Schema do
  @moduledoc """
  Shared schema conventions: `binary_id` primary and foreign keys, `utc_datetime`
  timestamps. Use in place of `use Ecto.Schema`.
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime]
    end
  end
end
