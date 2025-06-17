defmodule NetsukeAgents.AgentServer do
  use GenServer

  alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}
  alias NetsukeAgents.Commands.CreateAgent
  alias NetsukeAgents.Commands.ReceiveInput
  alias NetsukeAgents.Commands.CompleteResponse
  alias NetsukeAgents.CommandedApp
  alias NetsukeAgents.Events.{InputReceived, ResponseCompleted}
  alias Phoenix.PubSub

  # Public API

  def start_link(agent_id) do
    GenServer.start_link(__MODULE__, agent_id, name: via_tuple(agent_id))
  end

  def run(agent_id, input) do
    # Increase timeout from default 5000ms to 30000ms (30 seconds) for complex responses
    GenServer.call(via_tuple(agent_id), {:run, input}, 30000)
  end

  # Server callbacks

  def init(agent_id) do
    # 1) Crea el aggregate si no existe
    %CreateAgent{agent_id: agent_id, initiator: "system"}
    |> CommandedApp.dispatch()

    # 2) Suscribe este GenServer a los eventos del agente
    :ok = PubSub.subscribe(NetsukeAgents.PubSub, "agent:#{agent_id}")

    # Create new agent with initial memory
    initial_memory =
      AgentMemory.new()
      |> AgentMemory.add_message("assistant", %{reply: "Hello! How can I assist you today?"})

    config = %BaseAgentConfig{memory: initial_memory}
    agent = BaseAgent.new(agent_id, config)

    {:ok, agent}
  end

  # def init(agent_id) do
  #   case reconstruct_agent_state(agent_id) do
  #     nil ->
  #       # Create new agent with initial memory
  #       initial_memory =
  #         AgentMemory.new()
  #         |> AgentMemory.add_message("assistant", %{reply: "Hello! How can I assist you today?"})

  #       config = %BaseAgentConfig{memory: initial_memory}
  #       agent = BaseAgent.new(agent_id, config)

  #       # Log agent creation event
  #       {:ok, _} = log_event("agent_created", agent_id, %{initial_config: %{has_greeting: true}})

  #       {:ok, agent}

  #     agent ->
  #       # Agent reconstructed from events
  #       {:ok, agent}
  #   end
  # end

  def handle_call({:run, input_text}, _from, agent = %BaseAgent{}) do
    input = %{chat_message: input_text}  # TODO: usar schema de entrada

    correlation_id = UUID.uuid4()

    # 3) Dispatch de ReceiveInput
    %ReceiveInput{
      agent_id: agent.id,
      input: %{chat_message: input_text},  # TODO: usar schema de entrada
      correlation_id: correlation_id
    }
    |> CommandedApp.dispatch()

    # 4) Procesa localmente con BaseAgent (replay + run)
    {:ok, updated_agent, output} = BaseAgent.run(agent, input)

    # 5) Dispatch de CompleteResponse
    %CompleteResponse{
      agent_id: agent.id,
      output: output,  # TODO: usar schema de salida
      caused_by_correlation_id: correlation_id
    }
    |> CommandedApp.dispatch()

    {:reply, output, updated_agent}
  end

  # 6) Handle de notificaciones PubSub

  # Evento de input recibido
  def handle_info({:input, %InputReceived{input: input, correlation_id: corr}}, state) do
    # opcional: notificar UI / logs
    IO.puts("[#{state.agent_id}] input recibido: #{inspect(input)} (corr=#{corr})")
    {:noreply, state}
  end

  # Evento de respuesta completada
  def handle_info({:response, %ResponseCompleted{output: %{reply: reply}, caused_by_correlation_id: corr}}, state) do
    # Aquí se entrega la respuesta al chat/orquestador
    IO.puts("[#{state.agent_id}] respuesta del agente: #{reply} (corr=#{corr})")
    {:noreply, state}
  end

  # Helper para via tuple
  defp via_tuple(agent_id) do
    {:via, Registry, {NetsukeAgents.AgentRegistry, agent_id}}
  end
end
