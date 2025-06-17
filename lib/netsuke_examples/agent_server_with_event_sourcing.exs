# Test script for Agent Event Sourcing
alias NetsukeAgents.{AgentSupervisor, AgentServer, AgentEvent}

defmodule AgentTester do
  def run(start_observer \\ false) do
    if start_observer do
      IO.puts("Starting Observer - check for new window")
      :observer.start()
    end

    # Generate a unique agent ID for testing
    agent_id = "test_agent_#{:os.system_time(:millisecond)}"
    IO.puts("Starting agent with ID: #{agent_id}")

    # Start a new agent
    {:ok, _pid} = AgentSupervisor.start_agent(agent_id)

    # Send a sequence of messages
    messages = [
      "Hello! How are you today?",
      "What can you tell me about event sourcing in two sentences?",
      "Is Elixir a good option to implement event sourcing? It's a yes or no question.",
    ]

    # Process each message and collect responses
    responses = Enum.map(messages, fn message ->
      IO.puts("\n----\nSending: #{message}")

      try do
        response = AgentServer.run(agent_id, message)
        IO.puts("Response: #{response.reply}")
        response
      rescue
        e ->
          IO.puts("Error processing message: #{Exception.message(e)}")
          %{reply: "Error: #{Exception.message(e)}"}
      end
    end)

    # Get the event history
    IO.puts("\n\n== EVENT HISTORY ==")
    events = AgentServer.get_history(agent_id)
    Enum.each(events, fn event ->
      IO.puts("#{event.id} | #{event.type} | #{event.inserted_at}")
      if event.type == "response_generated" do
        IO.puts("   Input: #{event.data["input"]["chat_message"]}")
        IO.puts("   Output: #{event.data["output"]["reply"]}")
        if event.data["caused_by_event_id"], do: IO.puts("   Caused by: #{event.data["caused_by_event_id"]}")
      end
    end)

    # Test replaying to different points
    IO.puts("\n\n== REPLAY TESTING ==")
    if length(events) >= 3 do
      # Get the ID of the sixth event (should be the last response_generated)
      sixth_event = Enum.at(events, 6)
      IO.puts("Replaying agent up to event #{sixth_event.id}")

      # Replay up to that event
      replayed_agent = AgentServer.replay_agent(agent_id, sixth_event.id)

      # Show the memory state of the replayed agent
      IO.puts("\nReplayed agent memory:")
      Enum.each(replayed_agent.config.memory.history, fn message ->
        IO.puts("#{message.role}: #{inspect(message.content)}")
      end)
    end

    # Clean up
    IO.puts("\n\n== CLEANUP ==")
    IO.puts("Stopping agent: #{agent_id}")
    AgentSupervisor.stop_agent(agent_id)

    # List running agents to confirm stop
    running = AgentSupervisor.list_running_agents()
    IO.puts("Running agents: #{inspect(running)}")

    # If observer is running, pause to allow inspection
    if start_observer do
      IO.puts("\nPausing to allow process inspection in Observer...")
      IO.puts("Press Enter to continue")
      IO.gets("")
    end

    :ok
  end
end

# Run the test with Observer
IO.puts("Starting Agent Event Sourcing Test with Observer")
AgentTester.run(true)

# import_file("lib/netsuke_examples/agent_server_with_event_sourcing.exs")
