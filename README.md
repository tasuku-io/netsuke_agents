# Netsuke Agents

![Netsuke Agents Logo](assets/images/netsuke_cover.png "Netsuke Agents Cover")

A flexible Elixir library for building, validating, and managing AI agents with structured memory and schema validation.

## Overview

Netsuke Agents provides a robust framework for creating and managing agent-based systems in Elixir. It offers:

- **Schema Validation** - Define and validate input/output schemas using Ecto
- **Memory Management** - Track and manage agent conversation history
- **Flexible Configuration** - Easily configure agents with custom behaviors
- **Type Safety** - Strong typing with comprehensive validation rules
- **Event Sourcing** - Full audit trail of agent interactions

## Installation

Add `netsuke_agents` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:netsuke_agents, "~> 0.1.0"}
  ]
end
```

## Overview

Creating an Agent

```elixir
alias NetsukeAgents.{BaseAgent, BaseAgentConfig, BaseIOSchema}

# Define input/output schemas
input_schema = BaseIOSchema.new(
  definition: %{
    query: %{
      type: :string,
      is_required: true,
      description: "The user's question"
    }
  }
)

output_schema = BaseIOSchema.new(
  definition: %{
    reply: %{
      type: :string,
      is_required: true,
      description: "The agent's response"
    }
  }
)

# Create agent config
config = %BaseAgentConfig{
  input_schema: input_schema,
  output_schema: output_schema
}

# Initialize agent
agent = BaseAgent.new("my-agent", config)
```
Running an agent:

```elixir
input = %{query: "What's the weather like today?"}

{updated_agent, output} = BaseAgent.run(agent, input)
IO.puts("Agent replied: #{output.reply}")
```

## Schema Definition

Netsuke Agents uses a schema-first approach for defining agent interactions:

```elixir
schema = BaseIOSchema.new(
  definition: %{
    field_name: %{
      type: :string,        # Type (:string, :integer, :boolean, :float, :list, :map, :atom)
      is_required: true,    # Whether the field is required
      description: "Field description",  # Human-readable description
      value: "Example"      # Optional default/example value
    }
  }
)
```

## Agent Memory

Agents maintain conversation history through their memory system:

```elixir
# Access agent's conversation history
memory = agent.memory

# Reset memory to initial state
fresh_agent = BaseAgent.reset_memory(agent)
```

## Configuration

Customize your agent's behavior through the `BaseAgentConfig` struct:

```elixir
config = %BaseAgentConfig{
  input_schema: input_schema,
  output_schema: output_schema,
  memory: AgentMemory.new(),  # Optional custom initial memory
  client: YourClient.new()    # Optional custom client implementation
}
```

## Event Sourcing

Netsuke Agents implements an event sourcing pattern for comprehensive auditing and state management:

```elixir
# Start a managed agent server (handles event logging automatically)
{:ok, _pid} = NetsukeAgents.AgentServer.start_link("agent-123")

# Run the agent through the server
output = NetsukeAgents.AgentServer.run("agent-123", %{chat_message: "Hello!"})
```

### Event Types

Every agent interaction is logged as an event:

- input_received - Records user inputs
- response_generated - Records agent responses

Benefits

- **Audit Trail** - Complete history of all agent interactions
- **Replay Capability** - Rebuild agent state from event history
- **Analysis** - Extract insights from historical agent behavior
- **Debugging** - Trace issues through the sequence of events

Querying Events

```elixir
# Example: Retrieve all events for a specific agent
events = NetsukeAgents.AgentEvent
  |> where([e], e.agent_id == ^agent_id)
  |> order_by([e], e.inserted_at)
  |> NetsukeAgents.Repo.all()
```

## Advanced Usage

More detailed examples and advanced usage patterns will be added as the library matures.

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

## License
This project is licensed under the MIT License—see the [LICENSE](LICENSE) file for details.

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.