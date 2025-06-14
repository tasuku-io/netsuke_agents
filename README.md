# Netsuke Agents

![Netsuke Agents Logo](assets/images/netsuke_cover.png)

A flexible Elixir library for building, validating, and managing AI agents with structured memory and schema validation.

## Overview

Netsuke Agents provides a robust framework for creating and managing agent-based systems in Elixir. It offers:

- **Schema Validation** - Define and validate input/output schemas
- **Memory Management** - Track and manage agent conversation history
- **Flexible Configuration** - Easily configure agents with custom behaviors
- **Type Safety** - Strong typing with comprehensive validation rules
- **Multi-Agent Workflows** - Chain agents together for complex reasoning tasks

## Installation

Add `netsuke_agents` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:netsuke_agents, "~> 0.1.0"}
  ]
end
```

## Usage Examples

### Creating an Agent

```elixir
alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}

# Set up initial memory for an agent
sushi_master_memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "Hello! I am an expert Sushi Master. I can tell you about ingredients, techniques, and recipes."
  })

# Create config with memory and custom output schema
sushi_master_config = BaseAgentConfig.new([
  memory: sushi_master_memory,
  output_schema: %{
    ingredients: :list,
    steps: list
  }
  ])
```

A dynamic schema module will be generated from the output_schema map of field definitions by `schema_factory.ex`.

```elixir
# Initialize the agent
sushi_master = BaseAgent.new("sushi-master-agent", agent_config)
```

### Running an Agent

```elixir
# Prepare input for the agent with default input schema
input = %{chat_message: "How do I make the perfect sushi rice?"}

# Run the agent
{:ok, updated_agent, response} = BaseAgent.run(sushi_master, input)
```

```bash
# IO.inspect(response)
%:DynamicSchema_ingredients_steps{
  ingredients: ["short-grain rice", "water", "rice vinegar", "sugar", "salt"],
  steps: ["Rinse the rice under cold water until the water runs clear.",
   "Soak the rice in water for 30 minutes, then drain.",
   "In a rice cooker, combine the rice and water in the ratio of 1:1.1.",
   "Cook the rice according to the rice cooker's instructions.",
   "Once cooked, let the rice sit covered for 10 minutes off heat.",
   "In a separate bowl, mix rice vinegar, sugar, and salt until dissolved.",
   "Gently fold the vinegar mixture into the rice using a wooden spatula, while fanning the rice to cool it."]
}

```

### Multi-Agent Workflow Example

Create a chain of agents that process information sequentially:

```elixir
# Process with first agent
input_for_sushi_master = %{chat_message: "How do I make the perfect sushi rice?"}
{:ok, updated_sushi_master, sushi_master_response} = BaseAgent.run(sushi_master, input_for_sushi_master)

# Set up initial memory for Food Critic
food_critic_memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "I am a Food Critic. I will concisely evaluate the accuracy from a provided recipie."
  })

# Create config with memory and both custom output schema and input schema
critic_config = BaseAgentConfig.new([
  memory: food_critic_memory,
  input_schema: %{ingredients: :list, steps: :list},
  output_schema: %{recipie_evaluation: :string}
])

# Initialize Food Critic agent
food_critic = BaseAgent.new("food-critic-agent", critic_config)

# Pass the structured output to second agent
{:ok, updated_food_critic, final_response} = BaseAgent.run(food_critic, sushi_master_response)
```

```bash
# IO.inspect(final_response)
%:DynamicSchema_recipie_evaluation{
  recipie_evaluation: "The provided recipe for sushi rice is accurate and follows essential steps for preparing the rice properly. Rinsing the rice, soaking it, and cooking it using the correct water ratio ensures the right texture. The mixing of vinegar, sugar, and salt adds flavor, which is essential for sushi rice. Overall, the recipe is clear and well-structured."
}
```

## Agent Configuration

Configure your agents with schemas for validation and structured responses:

### Simplest Configuration (WIP)

```elixir
agent_config = BaseAgentConfig.new([
  background: some_background_string,
  steps: some_steps_string,
  output_instructions: some_output_instructions_string
])
```

### TODO: Show different levels of configuration

## Agent Memory

Agents maintain conversation history through their memory system:

```elixir
# Create new memory
memory = AgentMemory.new()

# Add messages to memory
memory = memory |> AgentMemory.add_message("user", %{content: "Hello"})
memory = memory |> AgentMemory.add_message("assistant", %{content: "Hi there!"})

# Dump memory
...

# Load memory
...
```

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

## License

This project is licensed under the MIT License—see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.