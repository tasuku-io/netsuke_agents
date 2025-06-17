defmodule NetsukeAgents.Router do
  use Commanded.Commands.Router,
    application: NetsukeAgents.CommandedApp

  alias NetsukeAgents.Aggregates.AgentAggregate
  alias NetsukeAgents.Commands.{CreateAgent, ReceiveInput, CompleteResponse}

  dispatch [CreateAgent, ReceiveInput, CompleteResponse],
    to: AgentAggregate,
    identity: :agent_id
end
