defmodule NetsukeAgents.Repo do
  use Ecto.Repo,
    otp_app: :netsuke_agents,
    adapter: Ecto.Adapters.Postgres
end
