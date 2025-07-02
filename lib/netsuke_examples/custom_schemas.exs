# Ensure application and dependencies are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Custom I/O Schemas Example ===
Input Schema: %{
  dish_name: "string",
  extra_information: %{
    "type" => "array",
    "items" => %{
      "type" => "embeds_many",
      "schema" => %{
        "level" => "string"
    }}}}
---
Output Schema: {:array, {:embeds_many, %{
    english_name: :string,
    japanese_name: :string,
    quantity: :integer,
    unit: :string
  }}}
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}
alias NetsukeAgents.Components.SystemPromptGenerator

# Set up initial memory for Sushi Master
memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "Hello! I am an expert Japanese Chef. I can tell you everything about ingredients, techniques, and recipes."
  })

output_schema = %{
  # ingredients: %{:ingredient_name => :string, quantity: :string},
  ingredients: {:array, {:embeds_many, %{
    english_name: :string,
    japanese_name: :string,
    quantity: :integer,
    unit: :string
  }}},
  steps: {:array, {:embeds_many, %{step_number: :integer, description: :string}}}
}

# input_schema = %{
#       dish_name: :string,
#       extra_information: {
#         :array, {
#           :embeds_many, %{
#             level: :string
#           }
#         }
#       }
#     }

input_schema = %{
      dish_name: "string",
      extra_information: %{
        "type" => "array",
        "items" => %{
          "type" => "embeds_many",
          "schema" => %{
            "level" => "string"
          }
        }
      }
    }


custom_prompt = SystemPromptGenerator.new(
  background: ["Expert Japanese Chef with years of experience"],
  steps: ["Understand the user's query", "prepare a response according to the difficulty level stated by the user", "Provide detailed information"],
  output_instructions: ["Respond with clear and concise information"]
)

config = BaseAgentConfig.new([
  memory: memory,
  output_schema: output_schema,
  input_schema: input_schema,
  system_prompt_generator: custom_prompt
])

agent = BaseAgent.new("sushi-master", config)

# Verify the agent's output schema
IO.inspect(agent.output_schema, label: "Agent output schema")

# Verify the agent's input schema
IO.inspect(agent.input_schema, label: "Agent input schema")

# Define single input
input = "okonomiyaki"

IO.puts("\n=== Processing Query ===")
IO.puts("User: #{input}")

# Process with first agent (Sushi Master)
# input = %{items: [%{dish_name: "okonomiyaki"}]}
input = %{dish_name: "okonomiyaki", extra_information: [%{level: "beginner"}]}
{:ok, _updated_agent, response} = BaseAgent.run(agent, input)

IO.inspect(response, label: "\nAgent Response")

IO.puts("\n=== Processing completed ===")
