# scripts/test_agent_server.exs

Mix.Task.run("app.start") # Ensure the app and dependencies are started

import Ecto.Query

alias NetsukeAgents.{AgentServer, AgentEvent, Repo, BaseAgentConfig, AgentMemory}

agent_id = "test-agent-001"
input_text = "What's the latest revenue?"

# Start the agent server
{:ok, _pid} = AgentServer.start_link(agent_id)

# Set up initial memory with assistant greeting
initial_memory =
  AgentMemory.new()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %{reply: "Hello! How can I assist you today?"})
  end)

# Create config for the agent
config = %BaseAgentConfig{
  memory: initial_memory
}

# Run a request
IO.puts("\n💬 Sending message to agent...")
response = AgentServer.run(agent_id, input_text)
IO.puts("🤖 Response: #{response.reply}")

# Fetch events from DB
IO.puts("\n🧾 Fetching stored events:")
events =
  AgentEvent
  |> where([e], e.agent_id == ^agent_id)
  |> order_by([e], asc: e.inserted_at)
  |> Repo.all()

Enum.each(events, fn event ->
  IO.puts("🗂  Event [#{event.type}]")
  IO.puts("  ⏱  #{event.inserted_at}")
  IO.puts("  🔢 Turn: #{event.caused_by}")
  IO.puts("  📦 Data: #{inspect(event.data)}\n")
end)
