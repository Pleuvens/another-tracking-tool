defmodule AnotherTrackingTool.Integrations.Account do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Accounts.User
  alias AnotherTrackingTool.IntegrationSources

  schema "integration_accounts" do
    field :source, Ecto.Enum, values: IntegrationSources.all()
    field :external_id, :string
    field :external_name, :string

    belongs_to :user, User

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:source, :external_id, :external_name, :user_id])
    |> validate_required([:source, :external_id])
    |> unique_constraint([:source, :external_id])
  end
end
