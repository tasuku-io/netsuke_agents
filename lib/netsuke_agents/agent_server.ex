defmodule NetsukeAgents.AgentServer do
  use GenServer
  alias NetsukeAgents.BaseAgent

  # Client API
  def start_link({id, config}) do
    GenServer.start_link(__MODULE__, {id, config}, name: via_tuple(id))
  end

  @doc """
  Runs a message through the agent.

  * `session_id` - The ID of the agent session
  * `message` - A map containing the message data
  * `timeout` - Timeout in milliseconds (default: 30000)
  """
  def run(session_id, message, timeout \\ 30000)
  def run(session_id, message, timeout) when is_map(message) and is_integer(timeout) and timeout > 0 do
    GenServer.call(via_tuple(session_id), {:run, message, timeout})
  end
  def run(_session_id, message, timeout) when not is_map(message) do
    {:error, "Message must be a map"}
  end
  def run(_session_id, _message, timeout) when not is_integer(timeout) or timeout <= 0 do
    {:error, "Timeout must be a positive integer"}
  end

  # Server callbacks
  @impl true
  def init({id, config}) do
    {:ok, BaseAgent.new(id, config)}
  end

  @impl true
  def handle_call({:run, message, timeout}, _from, agent) do
    # Create a task that runs asynchronously but is linked to the current process
    task = Task.async(fn ->
      BaseAgent.run(agent, message)
    end)

    # Wait for the result with a timeout
    case Task.await(task, timeout) do
      {:ok, updated_agent, response} ->
        {:reply, {:ok, response}, updated_agent}
      error ->
        {:reply, error, agent}
    end
  end

  defp via_tuple(id), do: {:via, Registry, {NetsukeAgents.Registry, id}}
end
