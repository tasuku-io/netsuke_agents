defmodule NetsukeAgents.Commands.CompleteResponse do
  @moduledoc "Command to record the agent’s response"
  use Vex.Struct
  use ExConstructor

  defstruct [:agent_id, :output, :caused_by_correlation_id]

  validates :agent_id, uuid: true
  validates :output, map: true
  validates :caused_by_correlation_id, uuid: true
end
