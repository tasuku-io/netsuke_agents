defmodule NetsukeAgents.Events.AgentCreated do
  @moduledoc "Emitted when a new agent is created"
  @derive Jason.Encoder
  defstruct [:agent_id, :initiator, :metadata]
end
