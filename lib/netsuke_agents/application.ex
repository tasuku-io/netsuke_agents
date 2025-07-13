defmodule NetsukeAgents.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # children = [
    #   # Starts a worker by calling: NetsukeAgents.Worker.start_link(arg)
    #   # {NetsukeAgents.Worker, arg}
    # ]
    base_children = [
      {Registry, keys: :unique, name: NetsukeAgents.AgentRegistry},
      {Task.Supervisor, name: NetsukeAgents.TaskSupervisor},
      NetsukeAgents.AgentSupervisor,
      {Finch, name: NetsukeAgents.Finch}
    ]

    # Only add Repo if ecto_repos is configured
    children = case Application.get_env(:netsuke_agents, :ecto_repos, []) do
      [] -> base_children
      [_|_] -> [NetsukeAgents.Repo | base_children]
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NetsukeAgents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
