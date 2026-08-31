defmodule AnotherTrackingTool.Repo.Migrations.CreateIntegrationAccounts do
  use Ecto.Migration

  def change do
    create table(:integration_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string, null: false
      add :external_id, :string, null: false
      add :external_name, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integration_accounts, [:source, :external_id])
    create index(:integration_accounts, [:user_id])
  end
end
