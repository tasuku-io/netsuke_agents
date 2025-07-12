import Config
import Dotenvy

source!(".env")

run_supervised = System.get_env("RUN_SUPERVISED") ||
  try do
    env!("RUN_SUPERVISED")
  rescue
    _ -> nil
  end

if run_supervised == true do
  config :netsuke_agents, NetsukeAgents.Repo,
    database: "netsuke_agents_dev",
    username: "luis",
    password: "postgres",
    hostname: "localhost"

  config :netsuke_agents, ecto_repos: [NetsukeAgents.Repo]
end

api_key = case System.get_env("OPENAI_API_KEY") do
  nil ->
    env!("OPENAI_API_KEY")
  key when is_binary(key) ->
    key
end

allowed_hosts =
  System.get_env("ALLOWED_HOSTS", env!("ALLOWED_HOSTS"))
  |> String.split(",")
  |> Enum.map(&String.trim/1)

config :netsuke_agents,
  allowed_hosts: allowed_hosts

config :instructor,
  adapter: Instructor.Adapters.OpenAI,
  openai: [api_key: api_key]
