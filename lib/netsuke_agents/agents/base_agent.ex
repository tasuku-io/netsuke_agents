defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that provides the core functionality for handling chat interactions.
  """

  import Ecto.Changeset

  alias NetsukeAgents.{BaseAgentConfig, AgentMemory, BaseIOSchema}

  defstruct [
    :id,
    :client,
    :memory,
    :initial_memory,
    :current_user_input,
    :input_schema,
    :output_schema,
    :config
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          config: BaseAgentConfig.t(),
          memory: AgentMemory.t(),
          initial_memory: AgentMemory.t(),
          current_user_input: map() | nil,
          input_schema: BaseIOSchema.t(),
          output_schema: BaseIOSchema.t(),
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
      client: config.client
    }
  end

  @doc """
  Resets the memory to its initial state.
  """
  @spec reset_memory(t()) :: t()
  def reset_memory(%__MODULE__{} = agent) do
    %{agent | memory: AgentMemory.copy(agent.initial_memory)}
  end

  @doc """
  Obtains a response from the language model synchronously.
  """
  @spec get_response(t()) :: {:ok, String.t()} | {:error, any()} # Adjusted return type
  def get_response(%__MODULE__{} = agent) do
    _response_model = agent.config.output_schema # This is BaseIOSchema.t()
    # In a real scenario, you'd use the schema to structure/validate the LLM call
    {:ok, "This is a mocked response from the model."}
  end

  @doc """
  Runs the chat agent with the given user input synchronously.
  Validates the input against the agent's input_schema.
  """
  @spec run(t(), map()) :: {t(), map()}
  def run(%__MODULE__{} = agent, input) do
    # Validate input against schema
    validate_input_against_schema!(input, agent.input_schema.definition)

    memory =
      agent.memory
      |> AgentMemory.initialize_turn()
      |> AgentMemory.add_message("user", input)

    agent_with_user_message = %{agent | memory: memory, current_user_input: input}

    case get_response(agent_with_user_message) do
      {:ok, response_text} ->
        output = %{reply: response_text} # This should conform to output_schema
        # TODO: Validate output against agent.output_schema.definition here
        final_memory = AgentMemory.add_message(agent_with_user_message.memory, "assistant", output)
        {%{agent_with_user_message | memory: final_memory}, output}

      {:error, error_reason} ->
        raise "Error getting response from model: #{inspect(error_reason)}"
    end
  end

  defp validate_input_against_schema!(input_map, schema_definition) when is_map(input_map) and is_map(schema_definition) do
    # 1. Build a dynamic schema based on the schema_definition
    types = create_types_map(schema_definition)

    # 2. Create and validate a changeset
    changeset =
      {%{}, types}
      |> cast(input_map, Map.keys(types))
      |> validate_required(required_fields(schema_definition))
      |> apply_specific_type_validations(schema_definition) # Add this line
      |> validate_no_extra_fields(input_map, schema_definition)

    # 3. If the changeset has errors, raise them in a user-friendly format
    if changeset.valid? do
      :ok
    else
      error_messages = format_changeset_errors(changeset)
      raise ArgumentError, "Input validation failed: #{error_messages}"
    end
  end

  # Create a map of field names to their Ecto types
  defp create_types_map(schema_definition) do
    Enum.into(schema_definition, %{}, fn {field_name, field_spec} ->
      ecto_type = BaseIOSchema.convert_schema_type_to_ecto_type(field_spec.type)
      {field_name, ecto_type}
    end)
  end

  # Get list of required fields
  defp required_fields(schema_definition) do
    schema_definition
    |> Enum.filter(fn {_field_name, field_spec} -> field_spec.is_required end)
    |> Enum.map(fn {field_name, _field_spec} -> field_name end)
  end

  # Check for extra fields not defined in the schema
  defp validate_no_extra_fields(changeset, input_map, schema_definition) do
    schema_keys = Map.keys(schema_definition)
    input_keys = Map.keys(input_map)
    extraneous_keys = MapSet.difference(MapSet.new(input_keys), MapSet.new(schema_keys)) |> MapSet.to_list()

    if Enum.empty?(extraneous_keys) do
      changeset
    else
      add_error(changeset, :base, "Unknown field(s): #{inspect(extraneous_keys)}. Allowed fields are: #{inspect(schema_keys)}.")
    end
  end

  # Format changeset errors into a readable string
  defp format_changeset_errors(changeset) do
    errors = traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)

    # Convert errors to string with more detail
    errors
    |> Enum.map_join("; ", fn {k, v} ->
      if k == :base do
        # Handle base errors (like our unknown fields error)
        Enum.join(v, "; ")
      else
        # Show field name and all error messages for that field
        errors_description = Enum.join(v, ", ")
        "#{k}: #{errors_description}"
      end
    end)
  end

  # Helper to get a nice type name
  defp typeof(value) when is_binary(value), do: "string"
  defp typeof(value) when is_integer(value), do: "integer"
  defp typeof(value) when is_float(value), do: "float"
  defp typeof(value) when is_boolean(value), do: "boolean"
  defp typeof(value) when is_atom(value), do: "atom"
  defp typeof(value) when is_list(value), do: "list"
  defp typeof(value) when is_map(value), do: "map"
  defp typeof(_), do: "unknown"

  defp apply_specific_type_validations(changeset, schema_definition) do
    # Important: We need to validate against the RAW input values
    # NOT the already cast values (which might already be marked invalid)
    raw_input = changeset.params

    Enum.reduce(schema_definition, changeset, fn {field_name, field_spec}, acc_changeset ->
      # Get the raw value from params
      raw_value = Map.get(raw_input, to_string(field_name)) || Map.get(raw_input, field_name)

      # Only validate if the field is present in input
      if raw_value != nil do
        # Check the type directly instead of using validate_change
        type_valid = case field_spec.type do
          :string -> is_binary(raw_value)
          :integer -> is_integer(raw_value)
          :boolean -> is_boolean(raw_value)
          :atom -> is_atom(raw_value)
          :float -> is_float(raw_value)
          :list -> is_list(raw_value)
          :map -> is_map(raw_value)
          _ -> true # Unknown type, assume valid
        end

        # Add descriptive error if type is invalid
        if !type_valid do
          error_message = "must be a #{field_spec.type}, got #{inspect(raw_value)} (#{typeof(raw_value)})"
          Ecto.Changeset.add_error(acc_changeset, field_name, error_message)
        else
          acc_changeset
        end
      else
        acc_changeset
      end
    end)
  end
end
