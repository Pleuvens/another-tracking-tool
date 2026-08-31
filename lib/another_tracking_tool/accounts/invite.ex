defmodule AnotherTrackingTool.Accounts.Invite do
  use AnotherTrackingTool.Schema

  import Ecto.Changeset

  alias AnotherTrackingTool.Accounts.User

  schema "invites" do
    field :code, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :invited_by, User
    belongs_to :used_by, User

    timestamps()
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:code, :expires_at, :invited_by_id])
    |> validate_required([:code, :expires_at, :invited_by_id])
    |> unique_constraint(:code)
  end
end
