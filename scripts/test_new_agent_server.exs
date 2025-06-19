# Test script for Agent Event Sourcing with new AgentServer

# This script serves as the base for the Agent Server implementation
# and tests the event sourcing capabilities of the agent system.

Mix.Task.run("app.start") # Ensure the app and dependencies are started

# Start the AgentSupervisor if not part of application tree
{:ok, _sup} = NetsukeAgents.AgentSupervisor.start_link([])

alias NetsukeAgents.{AgentSupervisor, AgentServer}
alias Phoenix.PubSub
alias Commanded.EventStore.Adapters.EventStore
alias Commanded.EventStore.RecordedEvent
alias NetsukeAgents.CommandedApp

# Tester module
defmodule AgentTester do
  def run(start_observer \\ false) do
    if start_observer do
      IO.puts("Starting Observer - check for new window")
      :observer.start()
    end

    # Generate a unique agent ID for testing
    agent_id = "test_agent_#{:os.system_time(:millisecond)}"
    IO.puts("Starting agent with ID: #{agent_id}")

    # Start a new agent via the supervisor
    {:ok, _pid} = AgentSupervisor.start_agent(agent_id)

    # Subscribe to PubSub for real-time events from agent
    Phoenix.PubSub.subscribe(NetsukeAgents.PubSub, "agent:#{agent_id}")

    # Sequence of test messages
    messages = [
      "Hello! How are you today?",
      "What can you tell me about event sourcing in two sentences?",
      "Is Elixir a good option to implement event sourcing? It's a yes or no question."
    ]

    # Process each message and print reply directly
    Enum.each(messages, fn message ->
      IO.puts("
        ----
        Sending: #{message}"
      )
      output = AgentServer.run(agent_id, message)
      IO.puts("Response: #{output.reply}")  # Access the reply field
      # Drain PubSub notifications for this turn (mailbox draining pattern)
      receive do
        notif -> IO.inspect(notif, label: "PubSub notification")
      after
        200 -> :ok
      end
    end)

    # Fetch events from EventStore directly
    IO.puts("

      == EVENT HISTORY FROM EVENTSTORE =="
    )
    # Use the EventStore module directly - not through CommandedApp config
    stream_id = "#{agent_id}"

    # Option 1: Access via EventStore API
    {:ok, events} = NetsukeAgents.EventStore.read_stream_forward(stream_id)

    Enum.each(events, fn event ->
      IO.puts("Event at #{event.created_at}: #{inspect(event.event_type)}")
      IO.puts("  Data: #{inspect(event.data)}")
    end)

    # Cleanup: stop agent via supervisor
    IO.puts("

      == CLEANUP =="
    )
    IO.puts("Stopping agent: #{agent_id}")
    AgentSupervisor.stop_agent(agent_id)

    :ok
  end

  # Add this after your current event reading logic
  IO.puts("\n\n== FULL EVENT STORE LOG ==")

  # Alternative Option 2: List all streams first, then read each
  {:ok, stream_ids} = NetsukeAgents.EventStore.stream_names()

  IO.puts("\n\n== ALL STREAMS ==")
  IO.puts("Found #{length(stream_ids)} streams: #{inspect(stream_ids)}")
end

# Run the test with Observer
IO.puts("Starting Agent Event Sourcing Test with Observer")
AgentTester.run(true)


#  Notes
#  Generates a unique agent ID for each run
#  How does this ID relates to the process and the actual agent ID agent == aggregator?
