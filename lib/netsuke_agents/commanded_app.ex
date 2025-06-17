defmodule NetsukeAgents.CommandedApp do
  use Commanded.Application,
    otp_app: :netsuke_agents,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: NetsukeAgents.EventStore
    ],
    # pubsub: [  # Phoenix PubSub not working, not needed for mvp
    #   phoenix_pubsub: [
    #     name: NetsukeAgents.PubSub,
    #     adapter: Phoenix.PubSub
    #   ]
    # ],
    pubsub: :local,
    registry: :local
  router(NetsukeAgents.Router)
  # def init(config) do  # you can provide an optional init/1 function to provide runtime configuration
  #   {:ok, config}
  # end
end
