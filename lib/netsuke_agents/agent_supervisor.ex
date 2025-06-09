defmodule NetsukeAgents.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: NetsukeAgents.AgentRegistry},
      {NetsukeAgents.AgentSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: NetsukeAgents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# --- 4. Supervisor for Agents (lib/my_app/agent_supervisor.ex) ---
defmodule NetsukeAgents.AgentSupervisor do
  use DynamicSupervisor

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(agent_id) do
    child_spec = {NetsukeAgents.AgentServer, [agent_id: agent_id]}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
