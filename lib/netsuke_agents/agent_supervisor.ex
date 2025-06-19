defmodule NetsukeAgents.AgentSupervisor do
  use DynamicSupervisor
  alias NetsukeAgents.{BaseAgentConfig, AgentServer}

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(agent_id, config \\ BaseAgentConfig.new([])) do
    child_spec = {NetsukeAgents.AgentServer, {agent_id, config}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def start_agent_session(agent_name, user_id, config \\ BaseAgentConfig.new([])) do
    session_id = "#{agent_name}-#{user_id}"

    {:ok, pid} = NetsukeAgents.AgentSupervisor.start_agent(session_id, config)

    {:ok, session_id, pid}
  end

  def run_agent(session_id, message) do
    AgentServer.run(session_id, message)
  end
end
