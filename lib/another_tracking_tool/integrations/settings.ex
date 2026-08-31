defmodule AnotherTrackingTool.Integrations.Settings do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.IntegrationSources

  schema "integration_settings" do
    field :source, Ecto.Enum, values: IntegrationSources.all()
    field :secret, :string

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:source, :secret])
    |> validate_required([:source, :secret])
    |> unique_constraint(:source)
  end
end
