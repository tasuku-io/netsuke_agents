defmodule NetsukeAgents.BaseAgentConfig do
  @moduledoc """
  Configuration struct for initializing a BaseAgent.
  """

  alias NetsukeAgents.{AgentMemory, BaseIOSchema}

  defstruct [
    :client,
    model: "gpt-4o-mini",
    memory: AgentMemory.new(), # Default memory, can be overridden
    # system_prompt_generator: nil, # TODO: Implement system prompt generator
    system_role: "system",
    input_schema: BaseIOSchema.new(
        definition: %{
          chat_message: %{
            type: :string,
            is_required: true,
            description: "The text content of the user's chat message."
          }
        }
      ),
    output_schema: BaseIOSchema.new(
        definition: %{
          reply: %{
            type: :string,
            is_required: true,
            description: "The text content of the agent's reply."
          }
        }
      ),
    model_api_parameters: nil
  ]

  @type t :: %__MODULE__{
          client: any(), # Replace with actual client type later
          model: String.t(),
          memory: AgentMemory.t() | nil,
          system_role: String.t(),
          input_schema: BaseIOSchema.t(),
          output_schema: BaseIOSchema.t(),
          model_api_parameters: map() | nil
        }

  @doc """
  Creates a new `BaseAgentConfig` struct from the given attributes.

  Field types are validated at runtime by TypeCheck against the `t()` specification.
  It merges the provided `attrs` with the default values defined in the struct.
  If any field does not conform to its specified type, a `TypeCheck.TypeError` is raised.

  ## Examples

      iex> BaseAgentConfig.new(client: some_client_module)
      %BaseAgentConfig{client: some_client_module, model: "gpt-4o-mini", ...}

      iex> BaseAgentConfig.new(model: 123)
      ** (TypeCheck.TypeError) ...
  """
  @spec new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end
end
