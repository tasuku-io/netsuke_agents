defmodule NetsukeAgents.Repo.Migrations.CreateAgentEvents do
  use Ecto.Migration

  def change do
    create table(:agent_events) do
      add :agent_id, :string, null: false
      add :type, :string, null: false
      add :data, :map, null: false
      add :caused_by, :string
      timestamps()
    end
  end
end
