defmodule NetsukeAgents.Commands.CreateAgent do
  @moduledoc "Command to create a new agent"
  use Vex.Struct
  use ExConstructor

  @primary_key false
  defstruct [:agent_id, :initiator]

  validates :agent_id, uuid: true
  validates :initiator, presence: true
end
