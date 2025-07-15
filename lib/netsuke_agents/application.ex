defmodule NetsukeAgents.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Validate configuration at startup
    validate_config!()
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

  defp validate_config! do
    # Validate OpenAI API key
    case openai_api_key() do
      nil ->
        raise """
        OpenAI API key not configured. Set either:
        - Environment variable: OPENAI_API_KEY
        - Application config: config :instructor, openai: [api_key: "..."]
        - Application config: config :netsuke_agents, api_key: "..."
        """
      _key ->
        :ok
    end
  end

  defp openai_api_key do
    Application.get_env(:netsuke_agents, :api_key) ||
      get_in(Application.get_env(:instructor, :openai, []), [:api_key]) ||
      System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY not configured"
  end

  @doc """
  Gets the list of allowed hosts for HTTP requests.
  """
  def allowed_hosts do
    IO.inspect("pulling allowed hosts from wherever")
    Application.get_env(:netsuke_agents, :allowed_hosts) ||
      System.get_env("ALLOWED_HOSTS", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Checks if the application should run supervised (with Repo).
  """
  def supervised? do
    System.get_env("RUN_SUPERVISED", "false") == "true"
  end
end
