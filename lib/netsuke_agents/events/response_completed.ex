defmodule NetsukeAgents.Events.ResponseCompleted do
  @moduledoc "Emitted when an agent has generated a response"
  @derive Jason.Encoder
  defstruct [:agent_id, :output, :caused_by_correlation_id, :metadata]
end
