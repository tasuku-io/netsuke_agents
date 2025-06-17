defmodule NetsukeAgents.Events.InputReceived do
  @moduledoc "Emitted when an agent receives user input"
  @derive Jason.Encoder
  defstruct [:agent_id, :input, :correlation_id, :metadata]
end
