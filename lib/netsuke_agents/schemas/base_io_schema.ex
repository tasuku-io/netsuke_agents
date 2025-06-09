defmodule NetsukeAgents.Schemas.BaseIOSchema do
  @moduledoc """
  Base schema for agent input/output payloads.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @derive {Jason.Encoder, only: [:chat_message]}
  embedded_schema do
    field :chat_message, :string
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:chat_message])
    |> validate_required([:chat_message])
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(schema) do
      schema |> Map.from_struct() |> Jason.encode!()
    end
  end
end
