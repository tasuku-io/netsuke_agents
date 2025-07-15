import Config

# Load environment variables from .env file if it exists
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

# Only configure database if running supervised
if System.get_env("RUN_SUPERVISED", "false") == "true" do
  config :netsuke_agents, NetsukeAgents.Repo,
    database: System.get_env("DATABASE_NAME", "netsuke_agents_dev"),
    username: System.get_env("DATABASE_USER", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOST", "localhost")

  config :netsuke_agents, ecto_repos: [NetsukeAgents.Repo]
end
