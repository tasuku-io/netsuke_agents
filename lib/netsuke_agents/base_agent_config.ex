defmodule NetsukeAgents.DefaultInputSchema do
  use Ecto.Schema
  use Instructor
  import Ecto.Changeset

  @llm_doc """
  Schema for handling input messages to the agent.
  """

  @primary_key false
  embedded_schema do
    field :chat_message, :string
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_required([:chat_message])
  end
end

defmodule NetsukeAgents.DefaultOutputSchema do
  use Ecto.Schema
  use Instructor
  import Ecto.Changeset

  @llm_doc """
  Schema for handling output responses from the agent.
  """

  @primary_key false
  embedded_schema do
    field :reply, :string
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_required([:reply])
  end
end

defmodule NetsukeAgents.BaseAgentConfig do
  @moduledoc """
  Configuration struct for initializing a BaseAgent.
  """

  alias NetsukeAgents.AgentMemory
  # We'll create these schema modules next

  alias NetsukeAgents.DefaultInputSchema
  alias NetsukeAgents.DefaultOutputSchema

  defstruct [
    :client,
    :system_prompt,
    model: "gpt-4o-mini",
    memory: AgentMemory.new(), # Default memory, can be overridden
    system_role: "system",
    input_schema: DefaultInputSchema,
    output_schema: DefaultOutputSchema,
    model_api_parameters: %{temperature: 0.7}
  ]

  @type t :: %__MODULE__{
          client: any(), # Replace with actual client type later
          model: String.t(),
          memory: AgentMemory.t() | nil,
          system_role: String.t(),
          system_prompt: String.t() | nil,
          input_schema: module(),  # Changed from BaseIOSchema.t() to module()
          output_schema: module(),  # Changed from BaseIOSchema.t() to module()
          model_api_parameters: map() | nil
        }

  @doc """
  Creates a new `BaseAgentConfig` struct from the given attributes.

  ## Examples

      iex> BaseAgentConfig.new(client: some_client_module)
      %BaseAgentConfig{client: some_client_module, model: "gpt-4o-mini", ...}
  """
  @spec new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end
end
