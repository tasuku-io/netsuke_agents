defmodule NetsukeAgents.AgentSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(agent_id) do
    child_spec = {NetsukeAgents.AgentServer, agent_id}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_agent(agent_id) do
    case Registry.lookup(NetsukeAgents.AgentRegistry, agent_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        {:error, :not_found}
    end
  end

  def list_running_agents do
    Registry.select(NetsukeAgents.AgentRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end
end
