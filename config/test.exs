import Config

# Always configure PostgreSQL for test environment
config :netsuke_agents, NetsukeAgents.Repo,
  database: "netsuke_agents_test",
  username: "luis",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :netsuke_agents, ecto_repos: [NetsukeAgents.Repo]
