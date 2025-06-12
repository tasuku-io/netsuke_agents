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
  AgentMemory,
  BaseIOSchema
}

# Set up initial memory with assistant greeting
initial_memory =
  AgentMemory.new()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %{chat_message: "Hello! How can I assist you today?"})
  end)

IO.inspect(initial_memory, label: "Initial Memory")

# Create config for the agent
config = BaseAgentConfig.new([
  memory: initial_memory,
  input_schema: BaseIOSchema.new(
        definition: %{
          other_field: %{
            type: :string,
            description: "The text content of the user's chat message."
          },
          second_field: %{
            type: :string,
            description: "The text content of the user's chat message."
          }
        }
      )
])

# Initialize the agent
agent = BaseAgent.new("console-agent", config)
IO.inspect(agent.config.input_schema, label: "Initialized Agent input schema")

# Show initial system prompt and message
IO.puts("📝 System Prompt: [mocked]")
IO.puts("🧠 Agent: Hello! How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %{chat_message: user_input} # Validate against input schema
    {updated_agent, response} = BaseAgent.run(agent, input)

    IO.puts("🧠 Agent: #{response.reply}")
    loop.(loop, updated_agent)
  end
end

loop.(loop, agent)
