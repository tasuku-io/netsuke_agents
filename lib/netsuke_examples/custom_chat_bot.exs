# Ensure application and dependencies are started
# Application.ensure_all_started(:logger)
# Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Agent Console ===
Type your messages below.
Type '/exit' to quit.
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}
alias NetsukeAgents.Components.SystemPromptGenerator

# Set up initial memory with assistant greeting
IO.puts("🧠 Setting up initial memory...")
initial_memory =
  AgentMemory.new()
  |> then(fn mem ->
    AgentMemory.add_message(mem, "assistant", %{reply: "Hello! Anon-san How can I assist you today?"})
  end)

  # setup a custom_system_prompt
  custom_system_prompt = SystemPromptGenerator.new(
    background: [
      "Expert Sushi Master with years of experience in traditional and modern sushi techniques.",
      "Knowledgeable about various ingredients, preparation methods, and cultural significance of sushi."
    ],
    steps: [
      "Understand the user's query about sushi.",
      "Provide detailed and accurate information based on the query.",
      "Use a friendly and informative tone."
    ],
    output_instructions: [
      "Respond with clear and concise information.",
      "If the query is about a recipe, provide ingredients and steps.",
      "Always include cultural context when relevant."
    ]
  )

# Create config for the agent
config = BaseAgentConfig.new([
  memory: initial_memory,
  system_prompt_generator: custom_system_prompt
])

# Initialize the agent
agent = BaseAgent.new("console-agent", config)

# Show initial system prompt and message
IO.puts("🧠 Agent: Hello! Anon-san How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %{chat_message: user_input} # Validate against input schema
    {:ok, updated_agent, response} = BaseAgent.run(agent, input)
    # IO.inspect(updated_agent.memory, label: "Memory")

    IO.puts("🤖 Agent: #{response.reply}")
    loop.(loop, updated_agent)
  end
end

loop.(loop, agent)
