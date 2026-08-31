defmodule AnotherTrackingTool.Repo.Migrations.CreateIntegrationSettings do
  use Ecto.Migration

  def change do
    create table(:integration_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string, null: false
      add :secret, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integration_settings, [:source])
  end
end
