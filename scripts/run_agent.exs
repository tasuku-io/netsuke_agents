# Ensure application and dependencies are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Agent Console ===
Type your messages below.
Type '/exit' to quit.
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}

# Set up initial memory with assistant greeting
IO.puts("🧠 Setting up initial memory...")
initial_memory =
  AgentMemory.new()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %{reply: "Hello! I am an expert Sushi Master. How can I assist you today?"})
  end)

IO.inspect(initial_memory, label: "Initial Memory")

# Create config for the agent
config = BaseAgentConfig.new([
  memory: initial_memory,
  # input_schema: %{chat_message: :string},
  # output_schema: %{reply: :string}
])

# Initialize the agent
agent = BaseAgent.new("console-agent", config)

# Show initial system prompt and message
IO.puts("🧠 Agent: Hello! I am an expert Sushi Master. How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %{chat_message: user_input} # Validate against input schema
    {:ok, updated_agent, response} = BaseAgent.run(agent, input)

    IO.inspect(response)
    loop.(loop, updated_agent)
  end
end

loop.(loop, agent)
