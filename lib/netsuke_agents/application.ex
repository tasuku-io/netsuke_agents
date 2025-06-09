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
    children = [
      NetsukeAgents.Repo,
      {Registry, keys: :unique, name: NetsukeAgents.AgentRegistry},
      {NetsukeAgents.AgentSupervisor, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NetsukeAgents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
