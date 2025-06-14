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
  alias NetsukeAgents.DefaultInputSchema
  alias NetsukeAgents.DefaultOutputSchema
  alias NetsukeAgents.Factories.SchemaFactory
  alias NetsukeAgents.Components.SystemPromptGenerator

  defstruct [
    :client,
    :system_prompt,
    model: "gpt-4o-mini",
    memory: AgentMemory.new(),
    system_role: "system",
    input_schema: DefaultInputSchema,
    output_schema: DefaultOutputSchema,
    model_api_parameters: %{temperature: 0.7},
    system_prompt_generator: nil
  ]

  @type t :: %__MODULE__{
          client: any(), # Replace with actual client type later
          model: String.t(),
          memory: AgentMemory.t() | nil,
          system_role: String.t(),
          system_prompt: String.t() | nil,
          input_schema: module(),
          output_schema: module(),
          model_api_parameters: map() | nil,
          system_prompt_generator: SystemPromptGenerator.t() | nil
        }

  @doc """
  Creates a new `BaseAgentConfig` struct from the given attributes.

  If input_schema or output_schema are provided as maps, they will be converted
  to dynamic Ecto schemas using SchemaFactory.

  ## Examples

      iex> BaseAgentConfig.new(output_schema: %{ingredients: :list, steps: :list})
      %BaseAgentConfig{output_schema: DynamicSchema_ingredients_steps, ...}

      iex> BaseAgentConfig.new(input_schema: %{query: :string, options: :map})
      %BaseAgentConfig{input_schema: DynamicSchema_options_query, ...}
  """
  @spec new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    # Process output_schema
    attrs = Keyword.update(attrs, :output_schema, DefaultOutputSchema, fn schema ->
      case schema do
        %{} = map when map_size(map) > 0 ->
          dynamic_schema = SchemaFactory.create_schema(map)
          dynamic_schema
        _ ->
          schema
      end
    end)

    # Process input_schema
    attrs = Keyword.update(attrs, :input_schema, DefaultInputSchema, fn schema ->
      case schema do
        %{} = map when map_size(map) > 0 ->
          dynamic_schema = SchemaFactory.create_schema(map)
          dynamic_schema
        _ ->
          schema
      end
    end)

    struct(__MODULE__, attrs)
  end
end
