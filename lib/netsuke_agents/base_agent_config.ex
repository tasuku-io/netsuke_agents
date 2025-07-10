defmodule NetsukeAgents.DefaultInputSchema do
  use Ecto.Schema
  use Instructor
  import Ecto.Changeset

  @llm_doc """
  Schema for handling input messages to the agent.
  """

   @derive {Jason.Encoder, only: [:chat_message]}

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

  @derive {Jason.Encoder, only: [:reply]}

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
    :system_prompt,  # TODO: eveluate if this is being used
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
  to dynamic Ecto schemas using SchemaFactory. If they are provided as `nil`,
  they will fallback to the default schemas (DefaultInputSchema and DefaultOutputSchema).

  The function automatically normalizes string keys to atoms in schema maps, making it
  compatible with data from databases, JSON APIs, or configuration files. It also
  handles complex nested structures including embedded schemas for arrays.

  ## Examples

      iex> BaseAgentConfig.new(output_schema: %{ingredients: :list, steps: :list})
      %BaseAgentConfig{output_schema: DynamicSchema_ingredients_steps, ...}

      iex> BaseAgentConfig.new(input_schema: %{query: :string, options: :map})
      %BaseAgentConfig{input_schema: DynamicSchema_options_query, ...}

      iex> BaseAgentConfig.new(input_schema: nil, output_schema: nil)
      %BaseAgentConfig{input_schema: DefaultInputSchema, output_schema: DefaultOutputSchema, ...}

      # String keys are automatically converted to atoms
      iex> BaseAgentConfig.new(output_schema: %{"message" => :string, "status" => :integer})
      %BaseAgentConfig{output_schema: DynamicSchema_message_status, ...}

      # Complex nested schemas with embedded arrays
      iex> BaseAgentConfig.new(output_schema: %{
      ...>   "items" => {:array, {:embeds_many, %{"name" => :string, "quantity" => :integer}}}
      ...> })
      %BaseAgentConfig{output_schema: DynamicSchema_items, ...}
  """
  @spec new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    # Normalize schema options to handle both string and atom keys
    attrs = attrs
    |> normalize_schema_option(:input_schema)
    |> normalize_schema_option(:output_schema)

    # Process output_schema
    attrs = Keyword.update(attrs, :output_schema, DefaultOutputSchema, fn schema ->
      case schema do
        nil ->
          DefaultOutputSchema
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
        nil ->
          DefaultInputSchema
        %{} = map when map_size(map) > 0 ->
          dynamic_schema = SchemaFactory.create_schema(map)
          dynamic_schema
        _ ->
          schema
      end
    end)

    struct(__MODULE__, attrs)
  end

  # Private helper functions for normalizing schema keys

  defp normalize_schema_option(opts, schema_key) do
    case Keyword.get(opts, schema_key) do
      nil -> opts
      schema -> Keyword.put(opts, schema_key, normalize_schema(schema))
    end
  end

  # Handle JSON-schema-like maps at the top level
  defp normalize_schema(%{"type" => "array", "items" => items} = top_level) when map_size(top_level) == 2 do
    # This is a top-level schema definition, wrap it in a field map
    %{items: {:array, normalize_schema_value(items)}}
  end

  # Handle regular maps (field definitions)
  defp normalize_schema(schema) when is_map(schema) do
    Map.new(schema, fn {key, value} ->
      {string_to_atom(key), normalize_schema_value(value)}
    end)
  end

  # Pass through everything else (atoms, tuples, etc.)
  defp normalize_schema(value), do: value

  # Handle nested schema values
  defp normalize_schema_value(%{"type" => "array", "items" => items}) do
    {:array, normalize_schema_value(items)}
  end

  defp normalize_schema_value(%{"type" => "embeds_many", "schema" => schema}) do
    {:embeds_many, normalize_schema(schema)}
  end

  defp normalize_schema_value(%{"type" => type}) when is_binary(type) do
    String.to_atom(type)
  end

  # Handle regular maps in values
  defp normalize_schema_value(schema) when is_map(schema) do
    Map.new(schema, fn {key, value} ->
      {string_to_atom(key), normalize_schema_value(value)}
    end)
  end

  # Handle tuple-based schemas (already normalized)
  defp normalize_schema_value({:array, {:embeds_many, schema_map}}) when is_map(schema_map) do
    {:array, {:embeds_many, normalize_schema(schema_map)}}
  end

  defp normalize_schema_value({key, value}) when is_tuple({key, value}) do
    {normalize_schema_value(key), normalize_schema_value(value)}
  end

  # Handle string types
  defp normalize_schema_value(value) when is_binary(value) do
    String.to_atom(value)
  end

  # Handle lists
  defp normalize_schema_value(value) when is_list(value) do
    Enum.map(value, &normalize_schema_value/1)
  end

  # Pass through everything else (atoms, etc.)
  defp normalize_schema_value(value), do: value

  defp string_to_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> String.to_atom(key)
    end
  end

  defp string_to_atom(key) when is_atom(key), do: key
end
