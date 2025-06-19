# Netsuke Agents - Process-Based Agent Architecture

## Architecture Overview

Netsuke Agents implements a robust, production-ready agent architecture leveraging Elixir's concurrency model:

```
Application
    └── AgentSupervisor (DynamicSupervisor)
            ├── AgentServer ("agent-1") - Process
            ├── AgentServer ("agent-2") - Process
            └── AgentServer ("agent-3") - Process
```

Each agent runs as an independent, supervised process with Task-based execution for LLM interactions.

## Key Components

### AgentSupervisor

A DynamicSupervisor that manages the lifecycle of agent processes:

- Creates and monitors AgentServer instances
- Provides fault tolerance with automatic restart
- Supports session-based agent management
- Handles cleanup of terminated agents

### AgentServer

GenServer-based processes maintaining agent state:

- Each agent runs as a dedicated process
- Maintains conversation state between interactions
- Uses Task-based execution for non-blocking LLM calls
- Provides a clean, message-based API

### BaseAgent

The core agent implementation:

- Manages memory and conversation context
- Processes inputs and generates responses
- Runs as Task for high-latency LLM operations
- Offers structured input/output validation

## Benefits of This Architecture

- **State Management** -> GenServers maintain agent state (memory, configuration) across interactions without manual recursion
- **Concurrency** -> Multiple agents run simultaneously as separate processes, leveraging BEAM's concurrency model
- **Fault Isolation** -> Errors in one agent don't affect others; supervision ensures recovery from failures
- **Resource Efficiency** -> Lightweight processes (~2KB overhead) enable thousands of concurrent agent sessions
- **Non-blocking LLM Calls** -> Task-based execution prevents long LLM calls from blocking the agent process
- **Session Management** -> Support for user-specific agent sessions with isolated conversation contexts

## Implementation Examples

### AgentSupervisor

```elixir
defmodule NetsukeAgents.AgentSupervisor do
  use DynamicSupervisor
  
  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  def start_agent(agent_id, config \\ BaseAgentConfig.new([])) do
    child_spec = {NetsukeAgents.AgentServer, {agent_id, config}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
  
  def start_agent_session(agent_name, user_id, config \\ BaseAgentConfig.new([])) do
    session_id = "#{agent_name}-#{user_id}"
    {:ok, pid} = start_agent(session_id, config)
    {:ok, session_id, pid}
  end
  
  def run_agent(session_id, message) do
    AgentServer.run(session_id, message)
  end
end
```

### AgentServer with Task-Based Execution

```elixir
defmodule NetsukeAgents.AgentServer do
  use GenServer
  alias NetsukeAgents.BaseAgent
  
  # Client API
  def start_link({id, config}) do
    GenServer.start_link(__MODULE__, {id, config}, name: via_tuple(id))
  end
  
  def run(agent_id, message) do
    GenServer.call(via_tuple(agent_id), {:run, message})
  end
  
  # Server callbacks
  @impl true
  def init({id, config}) do
    {:ok, BaseAgent.new(id, config)}
  end
  
  @impl true
  def handle_call({:run, message}, _from, agent) do
    # Execute BaseAgent.run in a Task for non-blocking operation
    task = Task.async(fn ->
      BaseAgent.run(agent, %{chat_message: message})
    end)
    
    # Wait for result with timeout
    case Task.await(task, 30_000) do
      {:ok, updated_agent, response} ->
        {:reply, {:ok, response.reply}, updated_agent}
      error ->
        {:reply, error, agent}
    end
  end
  
  defp via_tuple(id), do: {:via, Registry, {NetsukeAgents.Registry, id}}
end
```

## Usage Examples

### Starting the Agent System

```elixir
# Start the registry
{:ok, _} = Registry.start_link(keys: :unique, name: NetsukeAgents.Registry)

# Start the supervisor
{:ok, _} = NetsukeAgents.AgentSupervisor.start_link([])

# Create agent configuration
config = NetsukeAgents.BaseAgentConfig.new([
  memory: initial_memory,
  system_prompt_generator: custom_system_prompt
])
```

### Creating a Single Agent

```elixir
# Start an agent server
{:ok, pid} = NetsukeAgents.AgentSupervisor.start_agent("sushi-bot", config)

# Chat with the agent
{:ok, response} = NetsukeAgents.AgentServer.run("sushi-bot", "How do I make nigiri?")
IO.puts("Agent response: #{response}")
```

### Managing User Sessions

```elixir
# Create a session for a specific user
{:ok, session_id, _pid} = NetsukeAgents.AgentSupervisor.start_agent_session(
  "travel-assistant",
  "user-123",
  config
)

# Chat with the session
{:ok, response} = NetsukeAgents.AgentSupervisor.run_agent(
  session_id,
  "I want to plan a trip to Japan"
)
```

## Advanced Usage

### Concurrent User Sessions

Multiple users can interact with their own instances of the same agent type:

```elixir
# User 1 session
{:ok, session_1, _} = AgentSupervisor.start_agent_session("support", "user-1", config)

# User 2 session
{:ok, session_2, _} = AgentSupervisor.start_agent_session("support", "user-2", config)

# Both operate independently with isolated state
{:ok, response_1} = AgentSupervisor.run_agent(session_1, "Help with order #1234")
{:ok, response_2} = AgentSupervisor.run_agent(session_2, "Question about shipping")
```