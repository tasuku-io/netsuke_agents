defmodule NetsukeAgents.AgentEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agent_events" do
    field :agent_id, :string
    field :type, :string
    field :data, :map
    field :caused_by, :string
    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:agent_id, :type, :data, :caused_by])
    |> validate_required([:agent_id, :type, :data])
  end
end
