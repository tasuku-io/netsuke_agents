defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that provides the core functionality for handling chat interactions, including managing memory,
  generating system prompts, and obtaining responses from a language model.
  """

  alias NetsukeAgents.{BaseAgentConfig, AgentMemory}
  alias NetsukeAgents.Schemas.BaseIOSchema

  defstruct [
    :id,
    :input_schema,
    :output_schema,
    :client,
    :model,
    :memory,
    :system_role,
    :initial_memory,
    :current_user_input,
    :model_api_parameters
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          input_schema: module(),
          output_schema: module(),
          client: any(),
          model: String.t(),
          memory: AgentMemory.t(),
          system_role: String.t(),
          initial_memory: AgentMemory.t(),
          current_user_input: String.t() | nil,
          model_api_parameters: map()
        }

  @spec new(String.t(), BaseAgentConfig.t()) :: t()
  def new(id, %BaseAgentConfig{} = config) do
    memory = config.memory || AgentMemory.new()

    # TODO: use BaseInputSchema and BaseOutputSchema

    %__MODULE__{
      id: id,
      input_schema: config.input_schema, # TODO: or BaseInputSchema as atomic_agents
      output_schema: config.output_schema,
      client: config.client,
      model: config.model,
      memory: memory,
      system_role: config.system_role,
      initial_memory: AgentMemory.copy(memory),
      current_user_input: nil,
      model_api_parameters: config.model_api_parameters || %{}
    }
  end

  @doc """
  Resets the memory to its initial state.
  """
  # agent = BaseAgent.reset_memory(agent) to bind a new version of agent with updated memory
  @spec reset_memory(t()) :: t()
  def reset_memory(%__MODULE__{} = agent) do
    %{agent | memory: AgentMemory.copy(agent.initial_memory)}
  end

  @doc"""
  Obtains a response from the language model synchronously.
  """
  @spec get_response(t()) :: String.t()
  def get_response(%__MODULE__{} = agent) do
    _response_model = agent.output_schema
    {:ok, "This is a mocked response from the model."}
  end

  @doc """
  Runs the chat agent with the given user input synchronously.
  If input is provided, it adds a user message; otherwise, it skips it.
  Returns the updated agent and the assistant's response.
  """
  @spec run(t(), BaseIOSchema.t()) :: {t(), BaseIOSchema.t()}
  def run(agent, %BaseIOSchema{} = input) do
    memory =
      agent.memory
      |> AgentMemory.initialize_turn()
      |> AgentMemory.add_message("user", input)

    do_run(agent, input, memory)
  end

  def run(agent, nil) do
    memory = agent.memory
    do_run(agent, nil, memory)
  end

  defp do_run(agent, input, memory) do
    # Update the agent struct with temp memory and current input
    agent = %{agent | memory: memory, current_user_input: input}

    {:ok, response_text} = get_response(agent)

    output = %BaseIOSchema{chat_message: response_text}
    memory = AgentMemory.add_message(memory, "assistant", output)

    {%{agent | memory: memory}, output}
  end
end
