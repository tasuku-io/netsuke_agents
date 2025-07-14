import Config

# Load environment variables from .env file manually
if File.exists?(".env") do
  File.read!(".env")
  |> String.split("\n", trim: true)
  |> Enum.reject(&String.starts_with?(&1, "#"))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] when key != "" and value != "" ->
        System.put_env(key, value)
      _ ->
        :ok
    end
  end)
end

# Runtime configuration - loaded when the application starts
run_supervised = System.get_env("RUN_SUPERVISED", "false")

if run_supervised == "true" do
  config :netsuke_agents, NetsukeAgents.Repo,
    database: System.get_env("DATABASE_NAME", "netsuke_agents_dev"),
    username: System.get_env("DATABASE_USER", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOST", "localhost")

  config :netsuke_agents, ecto_repos: [NetsukeAgents.Repo]
else
  IO.inspect("Running without supervision. Ecto Repo will not be started.", label: "Runtime Config")
end

# Validate required environment variables
api_key = System.get_env("OPENAI_API_KEY")
if is_nil(api_key) do
  raise """
  Environment variable OPENAI_API_KEY is missing.
  Please set it to your OpenAI API key.
  """
end

allowed_hosts =
  System.get_env("ALLOWED_HOSTS", "")
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

IO.inspect(allowed_hosts, label: "Allowed Hosts at runtime config")

config :netsuke_agents,
  allowed_hosts: allowed_hosts

config :instructor,
  adapter: Instructor.Adapters.OpenAI,
  openai: [api_key: api_key]
