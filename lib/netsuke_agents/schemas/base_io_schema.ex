defmodule NetsukeAgents.BaseIOSchema do
  @moduledoc """
  Defines the structure and rules for input/output schemas.
  A schema is a map where keys are field names (atoms) and values specify
  the field's type (as an atom), requirement, description,
  and an optional example/default value.
  """
  use TypeCheck

  @typedoc """
  Specification for a single field within a schema.
  - `value`: Optional example or default value for the field.
  - `type`: Atom representing the data type (e.g., `:string`, `:integer`, `MyApp.MyStruct`).
  - `is_required`: Boolean indicating if the field must be present.
  - `description`: String providing a description of the field.
  """
  @type! field_spec_t :: %{
    optional(:value) => any(),
    :type => atom(), # Changed from Macro.t()
    :is_required => boolean(),
    :description => String.t()
  }

  @typedoc """
  The type for the schema content itself.
  It's a map where keys are atoms (representing field names)
  and values are `field_spec_t()` definitions.
  Example: `%{user_query: %{type: :string, is_required: true, description: "The user's query"}}`
  """
  @type! schema_content_t :: map(atom(), field_spec_t())

  defstruct [
    definition: %{}
  ]

  @type! t :: %__MODULE__{
    definition: schema_content_t()
  }

  @doc """
  Creates a new `BaseIOSchema` struct.
  The input `:definition` map should use atoms for types (e.g., `:string`).
  If a field specification omits `:is_required`, it defaults to `false`.
  """
  @spec! new(attrs :: keyword()) :: t()
  def new(attrs \\ []) do
    input_definition_map = Keyword.get(attrs, :definition, %{})

    processed_definition_map =
      Enum.into(input_definition_map, %{}, fn {field_name, field_spec_input} ->
        if is_map(field_spec_input) do
          type_atom = Map.get(field_spec_input, :type)
          unless is_atom(type_atom) do
            raise ArgumentError, "Field :#{Atom.to_string(field_name)} spec must have a :type atom. Got: #{inspect(type_atom)}"
          end

          description = Map.get(field_spec_input, :description)
          unless is_binary(description) do
            raise ArgumentError, "Field :#{Atom.to_string(field_name)} spec must have a :description string. Got: #{inspect(description)}"
          end

          defaulted_field_spec = Map.put_new(field_spec_input, :is_required, false)
          {field_name, defaulted_field_spec}
        else
          raise ArgumentError, "Field spec for :#{Atom.to_string(field_name)} must be a map. Got: #{inspect(field_spec_input)}"
        end
      end)

    final_attrs = Keyword.put(attrs, :definition, processed_definition_map)
    struct!(__MODULE__, final_attrs)
  end
end
