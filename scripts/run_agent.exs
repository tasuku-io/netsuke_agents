# scripts/run_console_agent.exs

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
  AgentMemory,
  Schemas.BaseIOSchema
}

# Set up initial memory
initial_memory =
  AgentMemory.new()
  |> AgentMemory.initialize_turn()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %BaseIOSchema{chat_message: "Hello! How can I assist you today?"})
  end)

# Initialize the agent with memory
agent = %BaseAgent{
  id: "console-agent",
  memory: initial_memory,
  system_role: "system",
  model: "mock-model",
  model_params: %{}
}

# Show initial system prompt and message
IO.puts("📝 System Prompt: [mocked]")
IO.puts("🧠 Agent: Hello! How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %BaseIOSchema{chat_message: user_input}
    {updated_agent, response} = BaseAgent.run(agent, input)

    IO.puts("🧠 Agent: #{response.chat_message}")
    # IO.puts("📝 Memory:")
    # IO.puts(BaseAgent.get_memory_string(updated_agent))

    loop.(loop, updated_agent)
  end
end

loop.(loop, agent)
