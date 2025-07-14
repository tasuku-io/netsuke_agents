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

  @doc """
  Gets the OpenAI API key from application config.
  Falls back to system environment if not configured.
  """
  def openai_api_key do
    Application.get_env(:instructor, :openai)[:api_key] ||
      System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY not configured"
  end

  @doc """
  Gets the list of allowed hosts for HTTP requests.
  """
  def allowed_hosts do
    Application.get_env(:netsuke_agents, :allowed_hosts, [])
  end

  @doc """
  Checks if the application should run supervised (with Repo).
  """
  def supervised? do
    System.get_env("RUN_SUPERVISED", "false") == "true"
  end
end
