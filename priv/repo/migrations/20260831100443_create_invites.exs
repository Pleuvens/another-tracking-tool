defmodule AnotherTrackingTool.Repo.Migrations.CreateInvites do
  use Ecto.Migration

  def change do
    create table(:invites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :expires_at, :utc_datetime, null: false

      add :invited_by_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :used_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invites, [:code])
  end
end
