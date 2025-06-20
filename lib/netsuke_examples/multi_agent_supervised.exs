alias NetsukeAgents.{BaseAgentConfig, AgentMemory, AgentSupervisor}
alias NetsukeAgents.Components.SystemPromptGenerator

{:ok, _} = Registry.start_link(keys: :unique, name: NetsukeAgents.Registry)

sushi_master_custom_prompt = SystemPromptGenerator.new(
  background: ["Expert Sushi Master with years of experience"],
  steps: ["Understand the user's query", "Provide detailed information"],
  output_instructions: ["Respond with clear and concise information"]
)

output_schema = %{ingredients: [:string], preparation_steps: [:list]}

sushi_master_config = BaseAgentConfig.new(
  [
    output_schema: output_schema,
    system_prompt_generator: sushi_master_custom_prompt
  ]
)

{:ok, sushi_master_session_id, _pid} = AgentSupervisor.start_agent_session("sushi-san", 1, sushi_master_config)

food_critic_custom_prompt = SystemPromptGenerator.new(
  background: ["Expert food critic with years of experience"],
  steps: [
    "Understand the user's recipe",
    "Evaluate the recipe's correctness",
    "Emit a constructive critic towards the recipe"
  ],
  output_instructions: ["Respond kindly but with strictness"]
)

food_critic_memory = AgentMemory.new() |> AgentMemory.add_message("assistant", %{reply: "Hello! Which recipe would you want me to evaluate?"})

food_critic_config = BaseAgentConfig.new(
  [
    memory: food_critic_memory,
    system_prompt_generator: food_critic_custom_prompt,
    input_schema: %{ingredients: [:string], preparation_steps: [:list]}
  ]
)

{:ok, food_critic_session_id, _pid} = AgentSupervisor.start_agent_session("critic-san", 1, food_critic_config)

sushi_master_input = %{chat_message: "What is the recipe for sushi?"}
{:ok, sushi_master_reply} = AgentSupervisor.run_agent(sushi_master_session_id, sushi_master_input)

IO.puts("\n🍣 Sushi Master Response:")
IO.inspect(sushi_master_reply, label: "Sushi Master Reply")

{:ok, food_critic_reply} = AgentSupervisor.run_agent(food_critic_session_id, sushi_master_reply)

IO.puts("\n👨‍🍳 Food Critic Response:")
IO.inspect(food_critic_reply, label: "Food Critic Reply")
