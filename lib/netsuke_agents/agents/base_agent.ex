defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that provides the core functionality for handling chat interactions, including managing memory,
  generating system prompts, and obtaining responses from a language model.
  """

  alias NetsukeAgents.{BaseAgentConfig, AgentMemory}

  defstruct [
    :id,
    :client,
    :memory,
    :initial_memory,
    :current_user_input,
    :input_schema,
    :output_schema,
    config: BaseAgentConfig
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          config: BaseAgentConfig.t(),
          memory: AgentMemory.t(),
          initial_memory: AgentMemory.t(),
          current_user_input: map() | nil,
          input_schema: map(),
          output_schema: map(),
          client: any() | nil # TODO: nullable for now
        }

  @spec new(String.t(), BaseAgentConfig.t()) :: t()
  def new(id, %BaseAgentConfig{} = config) do
    memory = config.memory || AgentMemory.new()

    %__MODULE__{
      id: id,
      config: config,
      memory: memory,
      initial_memory: memory,
      current_user_input: nil,
      input_schema: config.input_schema,
      output_schema: config.output_schema,
      client: nil
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

  @doc """
  Obtains a response from the language model synchronously.
  """
  @spec get_response(t()) :: String.t()
  def get_response(%__MODULE__{} = agent) do
    _response_model = agent.config.output_schema
    {:ok, "This is a mocked response from the model."}
  end

  @doc """
  Runs the chat agent with the given user input synchronously.
  If input is provided, it adds a user message; otherwise, it skips it.
  Returns the updated agent and the assistant's response.
  """
  @spec run(t(), map()) :: {t(), map()}
  def run(%__MODULE__{} = agent, input) do
    memory =
      agent.memory
      |> AgentMemory.initialize_turn()
      |> AgentMemory.add_message("user", input)

    agent = %{agent | memory: memory, current_user_input: input}

    {:ok, response_text} = get_response(agent)
    output = %{reply: response_text}
    memory = AgentMemory.add_message(memory, "assistant", output)

    {%{agent | memory: memory}, output}
  end

  # defp do_run(agent, input, memory) do
  #   # Update the agent struct with temp memory and current input
  #   agent = %{agent | memory: memory, current_user_input: input}

  #   {:ok, response_text} = get_response(agent)

  #   output = %{reply: response_text}
  #   memory = AgentMemory.add_message(memory, "assistant", output)

  #   {%{agent | memory: memory}, output}
  # end
end
