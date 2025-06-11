# Ensure application and dependencies are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Agent Console ===
Type your messages below.
Type '/exit' to quit.
""")

alias NetsukeAgents.{
  BaseAgent,
  BaseAgentConfig,
  AgentMemory
}

# Set up initial memory with assistant greeting
initial_memory =
  AgentMemory.new()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %{chat_message: "Hello! How can I assist you today?"})
  end)

# Create config for the agent
config = %BaseAgentConfig{
  memory: initial_memory
}

# Initialize the agent
agent = BaseAgent.new("console-agent", config)
IO.inspect(agent.memory, label: "Initialized Agent memory")

# Show initial system prompt and message
IO.puts("📝 System Prompt: [mocked]")
IO.puts("🧠 Agent: Hello! How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %{chat_message: user_input}
    {updated_agent, response} = BaseAgent.run(agent, input)
    IO.inspect(updated_agent.memory, label: "Updated Agent memory")

    IO.puts("🧠 Agent: #{response.reply}")
    loop.(loop, updated_agent)
  end
end

loop.(loop, agent)
