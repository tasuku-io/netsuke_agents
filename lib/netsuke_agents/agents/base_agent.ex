defmodule NetsukeAgents.BaseAgent do
  @moduledoc """
  A base agent that provides the core functionality for handling chat interactions.
  """

  import Ecto.Changeset

  alias NetsukeAgents.{BaseAgentConfig, AgentMemory}
  alias NetsukeAgents.Components.SystemPromptGenerator

  defstruct [
    :id,
    :client,
    :memory,
    :initial_memory,
    :current_user_input,
    :input_schema,
    :output_schema,
    :config,
    :system_prompt_generator
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          config: BaseAgentConfig.t(),
          memory: AgentMemory.t(),
          initial_memory: AgentMemory.t(),
          current_user_input: map() | nil,
          input_schema: module(),
          output_schema: module(),
          client: any() | nil, # TODO: nullable for now
          system_prompt_generator: SystemPromptGenerator.t()
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
      client: config.client,
      system_prompt_generator: config.system_prompt_generator || SystemPromptGenerator.new()
    }
  end

  @doc """
  Resets the memory to its initial state.
  """
  @spec reset_memory(t()) :: t()
  def reset_memory(%__MODULE__{} = agent) do
    %{agent | memory: AgentMemory.copy(agent.initial_memory)}
  end

  defp simplify_content(content) do
    try do
      # Convert struct to plain map to avoid Jason encoding issues with structs
      content_for_json = case content do
        %{__struct__: _} -> Map.from_struct(content)
        map when is_map(map) -> map
        other -> other
      end

      Jason.encode!(content_for_json, pretty: true)
    rescue
      # Fall back to inspect if JSON encoding fails
      _ -> inspect(content, pretty: true, limit: :infinity)
    end
  end

  @doc """
  Obtains a response from the language model synchronously using Instructor.

  The agent's `output_schema` field is expected to be an Ecto schema module.
  The agent's `client` field is expected to be an `Instructor.Client` (e.g., `Instructor.Client.OpenAI`).
  The agent's `config` should contain:
    - `model`: (string) The name of the language model (e.g., "gpt-3.5-turbo").
    - `system_prompt`: (string | nil) The system prompt for the agent.
    - `model_api_parameters`: (map | nil) Additional parameters for the LLM API (e.g., `%{temperature: 0.7}`).
  """
  @spec get_response(t()) :: {:ok, Ecto.Schema.t()} | {:error, any()}
  def get_response(%__MODULE__{} = agent) do

    system_prompt = [
      %{
        role: agent.config.system_role,
        content: SystemPromptGenerator.generate_prompt(agent.system_prompt_generator)
      }
    ]

    # TODO: Construct this using System Prompt Generator
    messages = system_prompt ++ Enum.map(AgentMemory.get_history(agent.memory), fn message ->
      %{
        role: message.role,
        content: simplify_content(message.content)
      }
    end)

    Instructor.chat_completion(
      model: agent.config.model,
      response_model: agent.output_schema,
      messages: messages #TODO: construct the content with system_prompt_generator
    )
  end

  @doc """
  Runs the chat agent with the given user input synchronously.
  Validates the input against the agent's input_schema.
  """
  @spec run(t(), map()) :: {:ok, t(), map()} | {:error, any()}
  def run(%__MODULE__{} = agent, input) do
    # Validate input against schema
    validate_input_against_schema!(input, agent.input_schema)

    memory =
      agent.memory
      |> AgentMemory.initialize_turn()
      |> AgentMemory.add_message("user", input)

      agent_with_user_message = %{agent | memory: memory, current_user_input: input}

    case get_response(agent_with_user_message) do
      {:ok, response} ->
        final_memory = AgentMemory.add_message(agent_with_user_message.memory, "assistant", response)
        updated_agent = %{agent_with_user_message | memory: final_memory}
        {:ok, updated_agent, response}  # Return the updated agent

      {:error, error_reason} ->
        raise "Error getting response from model: #{inspect(error_reason)}"
    end
  end

  def validate_input_against_schema!(input, schema_module) when is_map(input) do
    # Get the field names and embedded field names from the schema
    field_names = schema_module.__schema__(:fields)
    embed_names = schema_module.__schema__(:embeds)

    # Separate regular fields from embedded fields
    regular_fields = field_names -- embed_names

    # Create a changeset using cast for regular fields
    changeset = struct(schema_module) |> cast(input, regular_fields)

    # Add embedded fields using cast_embed with required: true for proper validation
    changeset = Enum.reduce(embed_names, changeset, fn embed_name, acc ->
      cast_embed(acc, embed_name, required: true)
    end)

    # Apply schema validation
    changeset = schema_module.validate_changeset(changeset)

    # If the changeset has errors, raise them in a user-friendly format
    if changeset.valid? do
      :ok
    else
      error_messages = format_changeset_errors(changeset)
      raise ArgumentError, "Input validation failed: #{error_messages}"
    end
  end

  # Format changeset errors into a readable string
  defp format_changeset_errors(changeset) do
    errors = traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        # Handle nested errors that might be maps
        formatted_value = case value do
          map when is_map(map) -> inspect(map)
          other -> to_string(other)
        end
        String.replace(acc, "%{#{key}}", formatted_value)
      end)
    end)

    # Convert errors to string with more detail
    format_error_map(errors)
  end

  # Helper function to format error maps (including nested embed errors)
  defp format_error_map(errors) when is_map(errors) do
    errors
    |> Enum.map_join("; ", fn {k, v} ->
      if k == :base do
        # Handle base errors
        format_error_value(v)
      else
        # Show field name and error details
        "#{k}: #{format_error_value(v)}"
      end
    end)
  end

  # Helper function to format different types of error values
  defp format_error_value(v) when is_list(v) do
    v
    |> Enum.map(&format_error_value/1)
    |> Enum.join(", ")
  end

  defp format_error_value(v) when is_map(v) do
    # Handle nested embed errors (like %{name: ["can't be blank"], age: ["is invalid"]})
    v
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{format_error_value(errors)}"
    end)
    |> then(&"[#{&1}]")
  end

  defp format_error_value(v) when is_binary(v), do: v
  defp format_error_value(v), do: to_string(v)
end
