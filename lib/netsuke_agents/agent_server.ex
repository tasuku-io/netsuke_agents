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

  # @impl true
  # def handle_call({:run, message}, _from, agent) do
  #   case BaseAgent.run(agent, %{chat_message: message}) do
  #     {:ok, updated_agent, response} ->
  #       {:reply, {:ok, response.reply}, updated_agent}
  #     error ->
  #       {:reply, error, agent}
  #   end
  # end

  @impl true
  def handle_call({:run, message}, _from, agent) do
    # Create a task that runs asynchronously but is linked to the current process
    task = Task.async(fn ->
      BaseAgent.run(agent, message)
    end)

    # Wait for the result with a timeout
    case Task.await(task, 30000) do
      {:ok, updated_agent, response} ->
        {:reply, {:ok, response}, updated_agent}
      error ->
        {:reply, error, agent}
    end
  end

  defp via_tuple(id), do: {:via, Registry, {NetsukeAgents.Registry, id}}
end
