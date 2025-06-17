defmodule NetsukeAgents.AgentServer do
  use GenServer
  alias NetsukeAgents.{BaseAgent, Repo, AgentEvent, BaseAgentConfig, AgentMemory}

  def start_link(agent_id) do
    GenServer.start_link(__MODULE__, agent_id, name: via_tuple(agent_id))
  end

  defp via_tuple(agent_id), do: {:via, Registry, {NetsukeAgents.AgentRegistry, agent_id}}

  def init(agent_id) do
    case reconstruct_agent_state(agent_id) do
      nil ->
        # Create new agent with initial memory
        initial_memory =
          AgentMemory.new()
          |> AgentMemory.add_message("assistant", %{reply: "Hello! How can I assist you today?"})

        config = %BaseAgentConfig{memory: initial_memory}
        agent = BaseAgent.new(agent_id, config)

        # Log agent creation event
        {:ok, _} = log_event("agent_created", agent_id, %{initial_config: %{has_greeting: true}})

        {:ok, agent}

      agent ->
        # Agent reconstructed from events
        {:ok, agent}
    end
  end

  def run(agent_id, input) do
    # Increase timeout from default 5000ms to 30000ms (30 seconds) for complex responses
    GenServer.call(via_tuple(agent_id), {:run, input}, 30000)
  end

  def handle_call({:run, input_text}, _from, agent = %BaseAgent{}) do
    input = %{chat_message: input_text}

    # Log input event
    {:ok, input_event_id} = log_event("input_received", agent.id, %{input: input})

    # Process the input
    {:ok, updated_agent, output} = BaseAgent.run(agent, input)

    # Convert output struct to map before logging if needed
    output_for_logging = case output do
      %{__struct__: _} -> Map.from_struct(output)
      _ -> output
    end

    # Log output event with causality link
    {:ok, _} = log_event("response_generated", updated_agent.id, %{
      input: input,
      output: output_for_logging,
      caused_by_event_id: input_event_id
    })

    {:reply, output, updated_agent}
  end

  def get_history(agent_id) do
    import Ecto.Query

    AgentEvent
    |> where([e], e.agent_id == ^agent_id)
    |> order_by([e], asc: e.inserted_at)
    |> Repo.all()
  end

  def replay_agent(agent_id, up_to_event_id \\ nil) do
    import Ecto.Query

    events_query = AgentEvent
                   |> where([e], e.agent_id == ^agent_id)
                   |> order_by([e], asc: e.inserted_at)

    events = if up_to_event_id do
      events_query
      |> where([e], e.id <= ^up_to_event_id)
      |> Repo.all()
    else
      events_query |> Repo.all()
    end

    base_agent = BaseAgent.new(agent_id, %BaseAgentConfig{memory: AgentMemory.new()})
    replay_events(base_agent, events)
  end

  defp log_event(type, agent_id, data) do
    %AgentEvent{}
    |> AgentEvent.changeset(%{
      type: type,
      agent_id: agent_id,
      caused_by: "agent_server",
      data: data,
      version: 1  # Add versioning for future compatibility
    })
    |> Repo.insert()
    |> case do
      {:ok, event} -> {:ok, event.id}
      error -> error
    end
  end

  defp reconstruct_agent_state(agent_id) do
    case load_agent_events(agent_id) do
      [] -> nil
      events ->
        # Start with empty agent
        base_agent = BaseAgent.new(agent_id, %BaseAgentConfig{memory: AgentMemory.new()})
        # Replay all events
        replay_events(base_agent, events)
    end
  end

  defp load_agent_events(agent_id) do
    import Ecto.Query

    AgentEvent
    |> where([e], e.agent_id == ^agent_id)
    |> order_by([e], asc: e.inserted_at)
    |> Repo.all()
  end

  defp replay_events(agent, events) do
    Enum.reduce(events, agent, &apply_event/2)
  end

  defp apply_event(event, agent) do
    case event.type do
      "agent_created" ->
        # Keep agent as is, already initialized
        agent

      "input_received" ->
        # No state change on input events
        agent

      "response_generated" ->
        # Update memory with the conversation
        input_text = get_in(event.data, ["input", "chat_message"])
        output = event.data["output"]

        updated_memory =
          agent.config.memory
          |> AgentMemory.add_message("user", %{content: input_text})
          |> AgentMemory.add_message("assistant", %{reply: output})

        %{agent | config: %{agent.config | memory: updated_memory}}

      _ ->
        # Unknown event type, keep agent unchanged
        agent
    end
  end
end
