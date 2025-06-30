# Ensure application and dependencies are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Single Query Two Agent Flow ===
First agent: Sushi Master 🍣
Second agent: Food Critic 🧐
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}

# Set up initial memory for Sushi Master
sushi_master_memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "Hello! I am an expert Sushi Master. I can tell you about ingredients, techniques, and recipes."
  })

# Create config for the Sushi Master agent
sushi_config = BaseAgentConfig.new([
  memory: sushi_master_memory,
  output_schema: %{
    ingredients: :list,
    steps: :list
  }
])

# Initialize Sushi Master agent
sushi_master = BaseAgent.new("sushi-master", sushi_config)

# Verify the agent's output schema
IO.inspect(sushi_master.output_schema, label: "Sushi master agent output schema")

# Set up initial memory for Food Critic
food_critic_memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "I am a Food Critic. I will concisely evaluate the accuracy from a provided recipie."
  })

# Create config for the Food Critic agent
critic_config = BaseAgentConfig.new([
  memory: food_critic_memory,
  input_schema: %{ingredients: :list, steps: :list},
  output_schema: %{recipie_evaluation: :string}
])

# Initialize Food Critic agent
food_critic = BaseAgent.new("food-critic", critic_config)

# Verify the agent's output schema
IO.inspect(food_critic.output_schema, label: "Food Critic agent output schema")

# Define single input
input = "How do I make perfect sushi rice?"

IO.puts("\n=== Processing Query ===")
IO.puts("User: #{input}")

# Process with first agent (Sushi Master)
input_for_sushi = %{chat_message: input}
{:ok, _updated_sushi_master, sushi_response} = BaseAgent.run(sushi_master, input_for_sushi)

IO.inspect(sushi_response, label: "\n🍣 Sushi Master Response")

# Process with second agent (Food Critic)
input_for_critic = sushi_response
# input_for_critic = %{
#   ingredients: sushi_response.ingredients,
#   steps: sushi_response.steps
# }
IO.inspect(input_for_critic, label: "Input for Food Critic")
{:ok, _updated_food_critic, critic_response} = BaseAgent.run(food_critic, input_for_critic)

IO.inspect(critic_response, label: "\n🧐 Food Critic Response")

IO.puts("\n=== Processing completed ===")
