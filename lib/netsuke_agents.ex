defmodule NetsukeAgents do
  @moduledoc """
  A flexible Elixir library for building, validating, and managing AI agents
  with structured memory and schema validation.

  Netsuke Agents provides a robust framework for creating and managing
  agent-based systems in Elixir. It offers:

  - **Schema Validation** - Define and validate input/output schemas
  - **Memory Management** - Track and manage agent conversation history
  - **Flexible Configuration** - Easily configure agents with custom behaviors
  - **Type Safety** - Strong typing with comprehensive validation rules
  - **Multi-Agent Workflows** - Chain agents together for complex reasoning tasks
  - **Process Architecture** - Each agent runs as an independent process for fault tolerance and concurrency

  ## Quick Start

  To create a basic agent:

      defmodule MyAgent do
        use NetsukeAgents.BaseAgent

        def config do
          %NetsukeAgents.BaseAgentConfig{
            name: "My Agent",
            description: "A simple example agent",
            instructions: "You are a helpful assistant."
          }
        end

        def handle_message(message, state) do
          # Your agent logic here
          {:ok, "Response to: \#{message}", state}
        end
      end

  ## Main Modules

  - `NetsukeAgents.BaseAgent` - Base behavior for creating agents
  - `NetsukeAgents.AgentServer` - GenServer implementation for agents
  - `NetsukeAgents.AgentSupervisor` - Supervisor for managing agent processes
  - `NetsukeAgents.Memory` - Memory management utilities
  - `NetsukeAgents.Schema` - Schema validation helpers
  """

  @doc """
  Returns the version of the NetsukeAgents library.

  ## Examples

      iex> NetsukeAgents.version()
      "0.0.1"

  """
  def version do
    Application.spec(:netsuke_agents, :vsn) |> to_string()
  end
end
