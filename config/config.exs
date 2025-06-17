import Config

config :netsuke_agents,
  event_stores: [NetsukeAgents.EventStore]

config :netsuke_agents, NetsukeAgents.Repo,
  database: "netsuke_agents_dev",
  username: "luis",
  password: "postgres",
  hostname: "localhost"

config :netsuke_agents, ecto_repos: [NetsukeAgents.Repo]

config :netsuke_agents, NetsukeAgents.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "luis",
  password: "postgres",
  database: "netsuke_eventstore_dev",
  hostname: "localhost",
  pool_size: 10
