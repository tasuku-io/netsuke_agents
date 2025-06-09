defmodule NetsukeAgents.AgentMessage do
  @moduledoc """
  Represents a message in the agent's memory, including role, content, and turn ID.
  """
  defstruct [:role, :content, :turn_id]
end

defmodule NetsukeAgents.AgentMemory do
  @moduledoc """
  Stores and manages an agent's conversational history with support for turns and roles.
  Includes serialization and turn-based message deletion.
  """

  alias NetsukeAgents.AgentMessage
  require Logger

  defstruct history: [], max_messages: nil, current_turn_id: nil

  @type t :: %__MODULE__{
          history: list(AgentMessage.t()),
          max_messages: integer() | nil,
          current_turn_id: String.t() | nil
        }

  @doc """
  Creates a new AgentMemory struct.
  """
  def new(opts \\ []) do
    %__MODULE__{
      max_messages: Keyword.get(opts, :max_messages),
      history: [],
      current_turn_id: nil
    }
  end

  @doc """
  Initializes a new conversation turn by generating a UUID.
  """
  def initialize_turn(memory) do
    %{memory | current_turn_id: UUID.uuid4()}
  end

  @doc """
  Adds a message to the memory with current or new turn ID.
  """
  def add_message(%__MODULE__{} = memory, role, content) when is_binary(role) do
    turn_id = memory.current_turn_id || UUID.uuid4()

    message = %AgentMessage{
      role: role,
      content: content,
      turn_id: turn_id
    }

    updated_history = memory.history ++ [message]

    new_history =
      if memory.max_messages && length(updated_history) > memory.max_messages do
        Enum.drop(updated_history, length(updated_history) - memory.max_messages)
      else
        updated_history
      end

    %__MODULE__{memory | history: new_history, current_turn_id: turn_id}
  end

  @doc """
  Retrieves messages formatted for LLM consumption.
  """
  def get_history(%__MODULE__{} = memory) do
    Enum.map(memory.history, fn %AgentMessage{role: role, content: content} ->
      %{role: role, content: Jason.encode!(content)}
    end)
  end

  @doc """
  Serializes the memory to a JSON string.
  """
  def dump(%__MODULE__{} = memory) do
    memory_map = %{
      history: Enum.map(memory.history, fn %AgentMessage{role: role, content: content, turn_id: turn_id} ->
        %{
          role: role,
          content: content,
          turn_id: turn_id
        }
      end),
      max_messages: memory.max_messages,
      current_turn_id: memory.current_turn_id
    }

    Jason.encode!(memory_map)
  end

  @doc """
  Loads AgentMemory from a JSON string.
  """
  def load(serialized) when is_binary(serialized) do
    with {:ok, decoded} <- Jason.decode(serialized),
         %{"history" => history, "max_messages" => max_messages, "current_turn_id" => current_turn_id} <- decoded do
      %__MODULE__{
        history: Enum.map(history, fn %{"role" => role, "content" => content, "turn_id" => turn_id} ->
          %AgentMessage{role: role, content: content, turn_id: turn_id}
        end),
        max_messages: max_messages,
        current_turn_id: current_turn_id
      }
    else
      error ->
        Logger.error("Failed to load AgentMemory: #{inspect(error)}")
        %__MODULE__{}
    end
  end

  @doc """
  Deletes all messages associated with a specific turn ID.
  """
  def delete_turn_id(%__MODULE__{} = memory, turn_id) do
    filtered = Enum.reject(memory.history, fn %AgentMessage{turn_id: tid} -> tid == turn_id end)

    new_turn_id =
      case filtered do
        [] -> nil
        [%AgentMessage{turn_id: last_tid} | _] -> last_tid
      end

    %__MODULE__{memory | history: filtered, current_turn_id: new_turn_id}
  end
end
