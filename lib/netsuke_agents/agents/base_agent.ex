defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that provides the core functionality for handling chat interactions, including managing memory,
  generating system prompts, and obtaining responses from a language model.
  """

  use TypeCheck

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
    Enum.each(schema_definition, fn {field_name, field_spec} ->
      is_required = field_spec.is_required
      type_atom_from_schema = field_spec.type # This is now an atom like :string or a Module name

      case Map.fetch(input_map, field_name) do
        {:ok, value} ->
          perform_type_check!(value, type_atom_from_schema, field_name)
        :error ->
          if is_required do
            raise ArgumentError, "Missing required input field :#{Atom.to_string(field_name)}."
          end
      end
    end)

    # Check for extraneous fields
    schema_keys = Map.keys(schema_definition)
    input_keys = Map.keys(input_map)
    extraneous_keys = MapSet.difference(MapSet.new(input_keys), MapSet.new(schema_keys)) |> MapSet.to_list()

    unless Enum.empty?(extraneous_keys) do
      raise ArgumentError, "Unknown input field(s): #{inspect(extraneous_keys)}. Allowed fields are: #{inspect(schema_keys)}."
    end
    :ok
  end

  # Helper function to perform type checking based on the type atom from the schema
  defp perform_type_check!(value, type_atom, field_name) do
    try do
      case type_atom do
        # TODO: Evaluate the types we want to support here.
        :string  -> TypeCheck.conforms!(value, String.t())
        :integer -> TypeCheck.conforms!(value, integer())
        :boolean -> TypeCheck.conforms!(value, boolean())
        :atom    -> TypeCheck.conforms!(value, atom())
        :float   -> TypeCheck.conforms!(value, float())
        :list    -> TypeCheck.conforms!(value, list(any()))
        :map     -> TypeCheck.conforms!(value, map())
        # Add more specific atoms if needed, e.g., :binary, :pid, etc.
        # :binary -> TypeCheck.conforms!(value, binary())
        # If you want a generic "is this a struct?" check, you could add:
        # :struct ->
        #   unless is_struct(value) do
        #     raise TypeCheck.TypeError, message: "Expected a struct, got: #{inspect(value)}"
        #   end
        #   :ok # or true, TypeCheck.conforms! expects :ok or raises

        _ ->
          raise ArgumentError, "Unsupported type atom ':#{type_atom}' in schema for field :#{Atom.to_string(field_name)}. Supported types are: :string, :integer, :boolean, :atom, :float, :list, :map."
      end
    rescue
      e in TypeCheck.TypeError ->
        reraise %ArgumentError{
          message: "Validation failed for field :#{Atom.to_string(field_name)} (expected type :#{type_atom}) - #{e.message}"
        }, __STACKTRACE__
      e in _ ->
        reraise %RuntimeError{
          message: "Unexpected error during type validation for field :#{Atom.to_string(field_name)} (type :#{type_atom}) - Value: #{inspect(value)}, Error: #{inspect(e)}"
        }, __STACKTRACE__
    end
    :ok
  end
end
