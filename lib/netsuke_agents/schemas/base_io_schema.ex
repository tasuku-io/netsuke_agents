defmodule NetsukeAgents.BaseIOSchema do
  @moduledoc """
  Defines the structure and rules for input/output schemas.
  A schema is a map where keys are field names (atoms) and values specify
  the field's type, requirement, description, and an optional example/default value.
  """
  use TypeCheck

  @typedoc """
  Specification for a single field within a schema.
  - `value`: Optional example or default value for the field.
  - `type`: Atom representing the data type (e.g., `:string`, `:integer`, `:boolean`).
  - `is_required`: Boolean indicating if the field must be present.
  - `description`: String providing a description of the field.
  """
  @type! field_spec_t :: %{
    optional(:value) => any(),
    :type => atom(),
    :is_required => boolean(),
    :description => String.t()
  }

  @typedoc """
  The type for the schema content itself.
  It's a map where keys are atoms (representing field names, i.e., `value_name`)
  and values are `field_spec_t()` definitions.
  Example: `%{user_query: %{value: "search term", type: :string, is_required: true, description: "The user's query"}}`
  """
  @type! schema_content_t :: map(atom(), field_spec_t())

  defstruct [
    # This field will hold the actual schema definition.
    definition: %{}
  ]

  @type! t :: %__MODULE__{
    definition: schema_content_t()
  }

  @doc """
  Creates a new `BaseIOSchema` struct, initialized with the given schema definition attributes.

  The `attrs` keyword list should typically contain a `:definition` key,
  whose value is a map conforming to `schema_content_t()`.
  If a field specification in the input definition omits `:is_required`, it defaults to `false`.
  Field types are validated at runtime by TypeCheck. If `attrs` is empty,
  a `BaseIOSchema` with an empty definition map is created.

  ## Examples

      iex> schema_data = %{
      ...>   item_name: %{type: :string, description: "Name of the item"}, # :is_required will default to false
      ...>   quantity: %{type: :integer, is_required: true, description: "Number of items", value: 1}
      ...> }
      iex> BaseIOSchema.new(definition: schema_data)
      %NetsukeAgents.BaseIOSchema{
        definition: %{
          item_name: %{type: :string, is_required: false, description: "Name of the item"},
          quantity: %{type: :integer, is_required: true, description: "Number of items", value: 1}
        }
      }

      iex> BaseIOSchema.new()
      %NetsukeAgents.BaseIOSchema{definition: %{}}

      iex> BaseIOSchema.new(definition: %{age: %{type: :integer, is_required: "yes"}})
      ** (TypeCheck.TypeError) ... an error is raised because "yes" is not a boolean for :is_required
  """
  @spec! new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    definition_map = Keyword.get(attrs, :definition, %{})

    processed_definition_map =
      Enum.into(definition_map, %{}, fn {field_name, field_spec} ->
        defaulted_field_spec =
          if is_map(field_spec) do
            Map.put_new(field_spec, :is_required, false) # Changed from put_if_absent
          else
            field_spec # Pass through non-map values; TypeCheck will validate later.
          end

        {field_name, defaulted_field_spec}
      end)

    final_attrs = Keyword.put(attrs, :definition, processed_definition_map)
    struct!(__MODULE__, final_attrs)
  end
end
