# Netsuke Agents

A flexible Elixir library for building, validating, and managing AI agents with structured memory and schema validation.

![Netsuke Agents Logo](assets/images/netsuke_cover.png)

> Netsuke (根付) were intricately carved Japanese toggles - small functional art pieces that secured valuable items to a kimono's sash. Like these hand-crafted treasures, Netsuke Agents are carefully designed to hold, manage, and connect your most valuable AI interactions, combining practicality with elegant design. Each agent, like each historical netsuke, should be crafted to be both beautiful in structure and purposeful in function.

## Overview

Netsuke Agents provides a robust framework for creating and managing agent-based systems in Elixir. It offers:

- **Schema Validation** - Define and validate complex input/output schemas
- **Memory Management** - Track and manage agent conversation history
- **Flexible Configuration** - Easily configure agents with custom behaviors
- **Type Safety** - Strong typing with comprehensive validation rules
- **Multi-Agent Workflows** - Chain agents together for complex reasoning tasks
- **Process Architecture** - Each agent runs as an independent process for fault tolerance and concurrency
- **🆕 Language Runtime** - Secure Lua execution environment for programmable agent plans

## Installation

Add `netsuke_agents` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:netsuke_agents, git: "https://github.com/tasuku-io/netsuke_agents", tag: "v0.0.1-alpha.5"}
  ]
end
```

Then run:

```bash
mix deps.get
```

Setup OpenAI API key in .env:

`OPENAI_API_KEY=your_openai_api_key`

### Configuration

If you want to use the built-in supervision tree and database functionality, add this to your application's supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # Your other children...
    NetsukeAgents.Repo,
    {Registry, keys: :unique, name: NetsukeAgents.AgentRegistry},
    {Task.Supervisor, name: NetsukeAgents.TaskSupervisor},
    NetsukeAgents.AgentSupervisor,
    # For Language Runtime HTTP tools
    {Finch, name: NetsukeAgents.Finch}
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Or you can use agents without the supervision tree for simpler use cases.

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
    ingredients: {:array, {:embeds_many, %{
      name: :string,
      quantity: :string,
      notes: :string
    }}},
    steps: {:array, {:embeds_many, %{
      order: :integer,
      instruction: :string,
      duration_minutes: :integer
    }}}
  }
  ])
```

A dynamic schema module will be generated from the output_schema map of field definitions by `schema_factory.ex`.

## Language Runtime

Netsuke Agents includes a secure **Language Runtime** system that allows agents to generate and execute Lua programs in a sandboxed environment. This enables programmable agent plans with safe access to external APIs.

### Key Features

- **Secure Sandbox**: Lua execution via Luerl with dangerous functions disabled
- **Tool System**: Safe HTTP requests and JSON processing
- **Agent Integration**: Agents can generate executable Lua plans
- **Security Model**: URL allowlists, timeout limits, and pattern detection

### Basic Language Runtime Usage

```elixir
alias NetsukeAgents.LuaExecutor

# Agent-generated Lua code
lua_code = """
function run(context)
  -- Fetch data from API
  local response = http.get("https://pokeapi.co/api/v2/pokemon/bulbasaur/")
  
  -- Parse JSON response
  local pokemon_data = json.decode(response)
  
  -- Extract specific fields
  context["pokemon_id"] = pokemon_data["id"]
  context["pokemon_name"] = pokemon_data["name"]
  
  return context
end
"""

# Execute in sandbox
{:ok, result} = LuaExecutor.execute(lua_code, %{})
# => %{"pokemon_id" => 1, "pokemon_name" => "bulbasaur"}
```

### Creating a Code-Generating Agent

```elixir
alias NetsukeAgents.Components.SystemPromptGenerator

# Configure agent to generate Lua programs
lua_agent_prompt = SystemPromptGenerator.new(
  background: [
    "You are a Lua Task Builder agent.",
    "Generate Lua functions that can be safely executed in a sandboxed environment.",
    "You have access to http.get() and json.decode() tools."
  ],
  steps: [
    "Read and understand the user's instruction.",
    "Generate Lua code with a function named `run(context)`.",
    "Use only safe Lua syntax and available tools.",
    "Return both the lua_code and context as an Elixir map."
  ],
  output_instructions: [
    "Output must be a map with `lua_code` and `context` keys.",
    "The lua_code must define `function run(context)` and return the context.",
    "Use triple-quoted strings for lua_code to preserve formatting."
  ]
)

lua_agent_config = BaseAgentConfig.new([
  system_prompt_generator: lua_agent_prompt,
  output_schema: %{
    lua_code: :string,
    context: :map
  }
])

lua_agent = BaseAgent.new("lua-generator", lua_agent_config)

# Generate executable code
{:ok, _agent, response} = BaseAgent.run(lua_agent, %{
  chat_message: "Write a program that fetches Pokemon data from PokeAPI"
})

# Execute the generated code
{:ok, result} = LuaExecutor.execute(response.lua_code, response.context)
```

### Available Tools

The Language Runtime provides these safe tools for Lua programs:

- **`http.get(url)`** - HTTP GET requests to allowlisted domains
- **`json.decode(json_string)`** - Parse JSON into Lua tables

### Security Features

- **Sandboxed Execution**: No access to `os`, `io`, `require`, or other dangerous functions
- **URL Allowlist**: Only approved domains can be accessed
- **Timeout Protection**: Configurable execution limits (default: 30 seconds)
- **Memory Limits**: Configurable memory constraints (default: 10MB)
- **Pattern Detection**: Advanced security validation to prevent bypass attempts

For detailed documentation, see the [Language Runtime README](lib/netsuke_agents/language_runtime/README.md).

## Schema Factory

The SchemaFactory dynamically generates Ecto schemas at runtime from simple map definitions, providing flexible type validation for agent inputs and outputs.

### Supported Field Types

- **Basic Types**: `:string`, `:integer`, `:float`, `:boolean`, `:map`
- **Arrays**: `{:array, :string}`, `{:array, :integer}`, etc.
- **Structured Arrays**: `{:array, {:embeds_many, schema_map}}` for arrays of structured maps
- **Backwards Compatibility**: `:list` (converted to `{:array, :string}`) and `:datetime` (converted to `:utc_datetime`)

### Examples

#### Simple Schema
```elixir
# Basic field types
output_schema = %{
  name: :string,
  age: :integer,
  tags: {:array, :string}
}
```

#### Complex Schema with Structured Arrays
```elixir
# Recipe with structured ingredients and steps
output_schema = %{
  recipe_name: :string,
  ingredients: {:array, {:embeds_many, %{
    name: :string,
    quantity: :string,
    unit: :string
  }}},
  steps: {:array, {:embeds_many, %{
    order: :integer,
    instruction: :string,
    duration_minutes: :integer
  }}}
}
```

#### Complex Schema with Structured Arrays (Map syntax)
```elixir
# Recipe with structured ingredients and steps with map syntax
output_schema = %{
  recipe_name: "string",
  ingredients: %{
    "type" => "array",
    "items" => %{
      "type" => "embeds_many",
      "schema" => %{
        "name" => "string",
        "quantity" => "string",
        "unit" => "string"
      }}},
  steps: %{
    "type" => "array",
    "items" => %{
      "type" => "embeds_many",
      "schema" => %{
        "order" => "integer",
        "instruction" => "string",
        "duration_minutes" => "integer"
      }}}
}
```

#### E-commerce Example
```elixir
# Product catalog with variants
output_schema = %{
  product_name: :string,
  description: :string,
  price: :float,
  variants: {:array, {:embeds_many, %{
    size: :string,
    color: :string,
    stock_count: :integer,
    sku: :string
  }}},
  reviews: {:array, {:embeds_many, %{
    rating: :integer,
    comment: :string,
    reviewer_name: :string
  }}}
}
```

The SchemaFactory automatically:
- Creates separate embedded schema modules for each structured array
- Handles validation for both parent and embedded schemas
- Generates deterministic module names for caching and reuse

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
  ingredients: [
    %{name: "short-grain rice", quantity: "2 cups", notes: "preferably Japanese variety"},
    %{name: "water", quantity: "2.2 cups", notes: "filtered water works best"},
    %{name: "rice vinegar", quantity: "1/4 cup", notes: "unseasoned"},
    %{name: "sugar", quantity: "2 tablespoons", notes: "white granulated"},
    %{name: "salt", quantity: "1 teaspoon", notes: "fine sea salt"}
  ],
  steps: [
    %{order: 1, instruction: "Rinse the rice under cold water until the water runs clear", duration_minutes: 5},
    %{order: 2, instruction: "Soak the rice in water for 30 minutes, then drain", duration_minutes: 30},
    %{order: 3, instruction: "Cook rice in rice cooker with 1:1.1 rice to water ratio", duration_minutes: 20},
    %{order: 4, instruction: "Let rice sit covered for 10 minutes off heat", duration_minutes: 10},
    %{order: 5, instruction: "Mix vinegar, sugar, and salt until dissolved", duration_minutes: 2},
    %{order: 6, instruction: "Fold vinegar mixture into rice while fanning to cool", duration_minutes: 8}
  ]
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
  input_schema: %{
    ingredients: {:array, {:embeds_many, %{
      name: :string,
      quantity: :string,
      notes: :string
    }}},
    steps: {:array, {:embeds_many, %{
      order: :integer,
      instruction: :string,
      duration_minutes: :integer
    }}}
  },
  output_schema: %{
    overall_rating: :integer,
    recipe_evaluation: :string,
    suggestions: {:array, :string}
  }
])

# Initialize Food Critic agent
food_critic = BaseAgent.new("food-critic-agent", critic_config)

# Pass the structured output to second agent
{:ok, updated_food_critic, final_response} = BaseAgent.run(food_critic, sushi_master_response)
```

```bash
# IO.inspect(final_response)
%:DynamicSchema_overall_rating_recipe_evaluation_suggestions{
  overall_rating: 9,
  recipe_evaluation: "Excellent traditional sushi rice recipe with proper techniques. The rice-to-water ratio is accurate, and the vinegar seasoning proportions are authentic. The step-by-step approach ensures proper texture and flavor development.",
  suggestions: [
    "Consider mentioning the importance of using a wooden or plastic paddle to avoid breaking rice grains",
    "Could add a note about the ideal serving temperature (body temperature, around 98°F)",
    "Suggest letting the seasoned rice rest for 5 minutes before use for optimal flavor integration"
  ]
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

## Using the System Prompt Generator

You can customize how your agent behaves by using the SystemPromptGenerator to inject a structured prompts:

```elixir
alias NetsukeAgents.Components.SystemPromptGenerator

# Create a custom system prompt generator
sushi_master_prompt = SystemPromptGenerator.new(
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

# Add the system prompt generator to the agent configuration
sushi_master_config = BaseAgentConfig.new([
  memory: sushi_master_memory,
  system_prompt_generator: sushi_master_prompt,
  output_schema: %{
    ingredients: :list,
    steps: :list
  }
])
```

### Context Provider (Not implemented yet)

For more advanced use cases, you can add context providers that dynamically inject information:

```elixir
defmodule SushiContextProvider do
  use NetsukeAgents.Components.SystemPromptContextProvider
  
  @impl true
  def get_info do
    """
    Common sushi ingredients:
    - Nori (seaweed)
    - Wasabi
    - Soy sauce
    - Pickled ginger (gari)
    - Various fish like tuna, salmon, yellowtail
    """
  end
end

# Add the context provider to your prompt generator
sushi_master_prompt = SystemPromptGenerator.new(
  # ... other configuration ...
  context_providers: %{
    "sushi_ingredients" => %{title: "Common Sushi Ingredients", provider: SushiContextProvider}
  }
)
```

The context will be automatically included in the system prompt used by the agent.

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

## Run Agents as Processes

Netsuke Agents implements a robust, production-ready architecture leveraging Elixir's concurrency model:

```
Application
    └── AgentSupervisor (DynamicSupervisor)
            ├── AgentServer ("agent-1") - Process
            ├── AgentServer ("agent-2") - Process
            └── AgentServer ("session-123") - Process
```

Each agent runs as an independent, supervised process with Task-based execution for LLM interactions.

### Key Benefits

- **State Management** -> GenServers maintain agent state (memory, configuration) across interactions without manual recursion
- **Concurrency** -> Multiple agents run simultaneously as separate processes, leveraging BEAM's concurrency model
- **Fault Isolation** -> Errors in one agent don't affect others; supervision ensures recovery from failures
- **Resource Efficiency** -> Lightweight processes (~2KB overhead) enable thousands of concurrent agent sessions
- **Non-blocking LLM Calls** -> Task-based execution prevents long LLM calls from blocking the agent process
- **Session Management** -> Support for user-specific agent sessions with isolated conversation contexts

### Using the Process Architecture

Start the Agent System:

```elixir
# Start the registry and supervisor
{:ok, _} = Registry.start_link(keys: :unique, name: NetsukeAgents.Registry)
{:ok, _} = NetsukeAgents.AgentSupervisor.start_link([])

# Create agent configuration
config = NetsukeAgents.BaseAgentConfig.new([
  memory: initial_memory,
  system_prompt_generator: custom_system_prompt
])

# Start an agent server
{:ok, pid} = NetsukeAgents.AgentSupervisor.start_agent("sushi-bot", config)

# Chat with the agent
{:ok, response} = NetsukeAgents.AgentServer.run("sushi-bot", "How do I make nigiri?")
```

#### User Sessions

Maintain separate agent instances for different users:

```elixir
# Create sessions for different users
{:ok, session_1, _} = AgentSupervisor.start_agent_session("support", "user-1", config)
{:ok, session_2, _} = AgentSupervisor.start_agent_session("support", "user-2", config)

# Both operate independently with isolated state
{:ok, response_1} = AgentSupervisor.run_agent(session_1, "Help with order #1234")
{:ok, response_2} = AgentSupervisor.run_agent(session_2, "Question about shipping")
```

#### Multi-Agent Workflow Example

Create a chain of agents that process information sequentially:

```elixir
alias NetsukeAgents.{BaseAgentConfig, AgentMemory, AgentSupervisor}
alias NetsukeAgents.Components.SystemPromptGenerator

# Start the registry (if not already started in your application)
{:ok, _} = Registry.start_link(keys: :unique, name: NetsukeAgents.Registry)

# Configure the Sushi Master agent with custom prompt and output schema
sushi_master_prompt = SystemPromptGenerator.new(
  background: ["Expert Sushi Master with years of experience in traditional and modern techniques"],
  steps: ["Understand the user's query", "Provide detailed and accurate information"],
  output_instructions: ["Respond with structured details about ingredients and preparation steps"]
)

sushi_master_config = BaseAgentConfig.new([
  output_schema: %{
    ingredients: {:array, {:embeds_many, %{
      name: :string,
      quantity: :string,
      preparation_notes: :string
    }}},
    preparation_steps: {:array, {:embeds_many, %{
      step_number: :integer,
      instruction: :string,
      estimated_time: :integer,
      technique: :string
    }}}
  },
  system_prompt_generator: sushi_master_prompt
])

# Start the Sushi Master agent as a supervised process with a unique session ID
{:ok, sushi_master_id, _pid} = AgentSupervisor.start_agent_session("sushi-master", "user-123", sushi_master_config)

# Configure the Food Critic agent with custom prompt, memory and input schema
food_critic_memory = AgentMemory.new() 
  |> AgentMemory.add_message("assistant", %{
    reply: "I am a Food Critic. I will evaluate the accuracy of provided recipes."
  })

food_critic_prompt = SystemPromptGenerator.new(
  background: ["Expert Food Critic specialized in evaluating culinary techniques"],
  steps: ["Analyze recipe ingredients and steps", "Evaluate authenticity and accuracy"],
  output_instructions: ["Provide a concise evaluation of the recipe"]
)

food_critic_config = BaseAgentConfig.new([
  memory: food_critic_memory,
  system_prompt_generator: food_critic_prompt,
  input_schema: %{
    ingredients: {:array, {:embeds_many, %{
      name: :string,
      quantity: :string,
      preparation_notes: :string
    }}},
    preparation_steps: {:array, {:embeds_many, %{
      step_number: :integer,
      instruction: :string,
      estimated_time: :integer,
      technique: :string
    }}}
  },
  output_schema: %{
    authenticity_score: :integer,
    technique_evaluation: :string,
    improvement_suggestions: {:array, :string}
  }
])

# Start the Food Critic agent as a supervised process with a unique session ID
{:ok, food_critic_id, _pid} = AgentSupervisor.start_agent_session("food-critic", "user-123", food_critic_config)

# Run the first agent with a question about sushi rice
{:ok, sushi_master_response} = AgentSupervisor.run_agent(sushi_master_id, %{
  chat_message: "How do I make the perfect sushi rice?"
})

# Pass the structured output from the first agent to the second agent
{:ok, critic_evaluation} = AgentSupervisor.run_agent(food_critic_id, sushi_master_response)

# The critic_evaluation now contains the food critic's assessment of the sushi recipe
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