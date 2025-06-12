defmodule NetsukeAgents.BaseIOSchema do
  @moduledoc """
  Defines the structure and rules for input/output schemas.
  A schema is a map where keys are field names (atoms) and values specify
  the field's type (as an atom), requirement, description,
  and an optional example/default value.
  """

  @type field_spec_t :: %{
    optional(:value) => any(),
    :type => atom(),
    :is_required => boolean(),
    :description => String.t()
  }

  @type schema_content_t :: %{atom() => field_spec_t()}

  defstruct [
    definition: %{}
  ]

  @type t :: %__MODULE__{
    definition: schema_content_t()
  }

  @supported_types [:string, :integer, :boolean, :atom, :float, :list, :map]

  @doc """
  Creates a new `BaseIOSchema` struct.
  The input `:definition` map should use atoms for types (e.g., `:string`).
  If a field specification omits `:is_required`, it defaults to `false`.
  """
  def new(attrs \\ []) do
    input_definition_map = Keyword.get(attrs, :definition, %{})

    processed_definition_map =
      Enum.into(input_definition_map, %{}, fn {field_name, field_spec_input} ->
        if is_map(field_spec_input) do
          # Validate :type is an atom and supported
          type_atom = Map.get(field_spec_input, :type)
          unless is_atom(type_atom) do
            raise ArgumentError, "Field :#{Atom.to_string(field_name)} spec must have a :type atom. Got: #{inspect(type_atom)}"
          end

          unless type_atom in @supported_types do
            raise ArgumentError, "Unsupported type atom ':#{type_atom}' for field :#{Atom.to_string(field_name)}. Supported types are: #{inspect(@supported_types)}."
          end

          # Validate :description is a string
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

  @doc """
  Converts the schema type atom to an Ecto type.
  """
  def convert_schema_type_to_ecto_type(:string), do: :string
  def convert_schema_type_to_ecto_type(:integer), do: :integer
  def convert_schema_type_to_ecto_type(:boolean), do: :boolean
  def convert_schema_type_to_ecto_type(:atom), do: :atom
  def convert_schema_type_to_ecto_type(:float), do: :float
  def convert_schema_type_to_ecto_type(:list), do: {:array, :any}
  def convert_schema_type_to_ecto_type(:map), do: :map
  # Add more conversions as needed
end
