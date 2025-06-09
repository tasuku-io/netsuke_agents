defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that takes input, builds a prompt, mocks a response,
  and returns an output using BaseIOSchema. Uses AgentMemory to manage chat state.
  """

  alias NetsukeAgents.{AgentMemory, AgentMessage}
  alias NetsukeAgents.Schemas.BaseIOSchema

  defstruct [
    :id,
    :memory,
    :system_role,
    :model,
    :model_params
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          memory: AgentMemory.t(),
          system_role: String.t() | nil,
          model: String.t(),
          model_params: map()
        }

  @spec new(String.t(), keyword()) :: t()
  def new(id, opts \\ []) do
    %__MODULE__{
      id: id,
      memory: AgentMemory.new(max_messages: Keyword.get(opts, :max_messages)),
      system_role: Keyword.get(opts, :system_role, "system"),
      model: Keyword.get(opts, :model, "mock-model"),
      model_params: Keyword.get(opts, :model_params, %{})
    }
  end

  @spec run(t(), BaseIOSchema.t()) :: {t(), BaseIOSchema.t()}
  def run(%__MODULE__{} = agent, %BaseIOSchema{} = input) do
    memory = AgentMemory.initialize_turn(agent.memory)
    memory = AgentMemory.add_message(memory, "user", input)

    prompt = build_prompt(agent, input, memory)

    output = %BaseIOSchema{chat_message: "[Mocked response to]: #{input.chat_message}"}
    memory = AgentMemory.add_message(memory, "assistant", output)

    {%{agent | memory: memory}, output}
  end

  defp build_prompt(agent, %BaseIOSchema{} = input, %AgentMemory{} = memory) do
    [
      (agent.system_role && "Role: #{agent.system_role}") || nil,
      "Memory: " <> format_memory(memory),
      "User: #{input.chat_message}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp format_memory(memory) do
    AgentMemory.get_history(memory)
    |> Enum.map(fn %{role: r, content: c} -> "#{r}: #{c}" end)
    |> Enum.join("\n")
  end
end
