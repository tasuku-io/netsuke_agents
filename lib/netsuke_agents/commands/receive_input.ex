defmodule NetsukeAgents.Commands.ReceiveInput do
  @moduledoc "Command to send user input into an agent"
  use Vex.Struct
  use ExConstructor

  @primary_key false
  defstruct [:agent_id, :input, :correlation_id]

  validates :agent_id, uuid: true
  validates :input, map: true
  validates :correlation_id, uuid: true
end
