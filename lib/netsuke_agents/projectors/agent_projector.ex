defmodule NetsukeAgents.Projectors.AgentProjector do
  use Commanded.Event.Handler,
    application: NetsukeAgents.CommandedApp,
    name: "AgentProjector"

  alias NetsukeAgents.Events.{InputReceived, ResponseCompleted}
  alias Phoenix.PubSub

  @impl true
  def handle(%InputReceived{agent_id: agent_id} = event, _metadata) do
    # Publica usando Phoenix.PubSub
    PubSub.broadcast!(NetsukeAgents.PubSub, "agent:#{agent_id}", {:input, event})
    :ok
  end

  @impl true
  def handle(%ResponseCompleted{agent_id: agent_id} = event, _metadata) do
    PubSub.broadcast!(NetsukeAgents.PubSub, "agent:#{agent_id}", {:response, event})
    :ok
  end
end
