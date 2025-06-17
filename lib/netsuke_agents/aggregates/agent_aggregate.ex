defmodule NetsukeAgents.Aggregates.AgentAggregate do
  @moduledoc "Event-sourced aggregate for a single Netsuke agent"

  # TODO: Configure snapshot_every: 500 or so to persist state periodically

  defstruct [:agent_id, :memory]

  alias __MODULE__
  alias NetsukeAgents.Commands.{CreateAgent, ReceiveInput, CompleteResponse}
  alias NetsukeAgents.Events.{AgentCreated, InputReceived, ResponseCompleted}

  # ----------------------
  # 1) Ejecutores (execute) de comandos
  # ----------------------

  # Crear un agente nuevo
  def execute(%AgentAggregate{agent_id: nil}, %CreateAgent{agent_id: id, initiator: user}) do
    %AgentCreated{
      agent_id: id,
      initiator: user,
      metadata: %{timestamp: DateTime.utc_now()}
    }
  end

  # Si ya existe, no hacemos nada
  def execute(%AgentAggregate{agent_id: id}, %CreateAgent{agent_id: id, initiator: _user}) do
    []
  end

  # Registrar entrada de usuario
  def execute(%AgentAggregate{agent_id: id}, %ReceiveInput{
        agent_id: id,
        input: input,
        correlation_id: corr
      }) do
    %InputReceived{
      agent_id: id,
      input: input,
      correlation_id: corr,
      metadata: %{timestamp: DateTime.utc_now()}
    }
  end

  # Completar respuesta del agente
  def execute(%AgentAggregate{agent_id: id}, %CompleteResponse{
        agent_id: id,
        output: out,
        caused_by_correlation_id: corr
      }) do
    %ResponseCompleted{
      agent_id: id,
      output: out,
      caused_by_correlation_id: corr,
      metadata: %{timestamp: DateTime.utc_now()}
    }
  end

  # ----------------------
  # 2) Aplicadores (apply) de eventos
  # ----------------------

  # Al crearse el agente, inicializamos memoria vacía
  def apply(%AgentAggregate{} = ag, %AgentCreated{agent_id: id, metadata: _meta}) do
    %AgentAggregate{ag | agent_id: id, memory: []}
  end

  # Al recibir input, opcionalmente lo almacenamos
  def apply(%AgentAggregate{memory: mem} = ag, %InputReceived{
        input: input,
        correlation_id: corr,
        metadata: _meta
      }) do
    entry = %{type: :input, data: input, correlation_id: corr}
    %AgentAggregate{ag | memory: mem ++ [entry]}
  end

  # Al completar respuesta, la agregamos a `memory`
  def apply(%AgentAggregate{memory: mem} = ag, %ResponseCompleted{
        output: out,
        caused_by_correlation_id: corr,
        metadata: _meta
      }) do
    entry = %{type: :assistant, data: out, correlation_id: corr}
    %AgentAggregate{ag | memory: mem ++ [entry]}
  end
end
