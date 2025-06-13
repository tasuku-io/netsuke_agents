defmodule NetsukeAgents.Factories.SchemaFactory do
  @moduledoc """
  Factory for dynamically generating Ecto schemas at runtime from simple map definitions.
  """

  @doc """
  Creates a dynamic schema module from a map of field definitions.

  ## Parameters
    * `field_map` - A map where keys are field names and values are field types

  ## Field Types
    * `:list` - Converted to `{:array, :string}` in Ecto
    * `:string` - Standard string field
    * `:integer` - Integer field
    * `:float` - Float field
    * `:boolean` - Boolean field
    * `:map` - Map field
    * `:datetime` - DateTime field

  ## Examples

      iex> SchemaFactory.create_schema(%{ingredients: :list, steps: :list})
      DynamicSchema_ingredients_steps
  """
  @spec create_schema(field_map :: map()) :: module()
  def create_schema(field_map) when is_map(field_map) do
    # Generate deterministic module name based on field keys (sorted for consistency)
    field_keys = field_map |> Map.keys() |> Enum.sort() |> Enum.join("_")
    module_name = :"DynamicSchema_#{field_keys}"

    # Check if module already exists to avoid redefining
    if Code.ensure_loaded?(module_name) do
      module_name
    else
      # Build the module with the specified fields
      fields_ast = for {field_name, field_type} <- field_map do
        actual_type = map_field_type(field_type)
        quote do
          field unquote(field_name), unquote(actual_type)
        end
      end

      required_fields = Map.keys(field_map)

      # Define the module
      ast = quote do
        defmodule unquote(module_name) do
          use Ecto.Schema
          use Instructor
          import Ecto.Changeset

          @llm_doc """
          Dynamically generated schema for agent IO.
          """

          @primary_key false
          embedded_schema do
            unquote_splicing(fields_ast)
          end

          @impl true
          def validate_changeset(changeset) do
            changeset
            |> validate_required(unquote(required_fields))
          end
        end
      end

      # Evaluate the module definition at runtime
      # Fix the pattern matching to correctly handle Code.eval_quoted return value
      {result, _bindings} = Code.eval_quoted(ast)

      case result do
        {:module, module, _binary, _fun} -> module
        _ -> raise "Failed to create dynamic schema module"
      end
    end
  end

  # Helper function to map simple type names to Ecto types
  defp map_field_type(:list), do: {:array, :string}
  defp map_field_type(:string), do: :string
  defp map_field_type(:integer), do: :integer
  defp map_field_type(:float), do: :float
  defp map_field_type(:boolean), do: :boolean
  defp map_field_type(:map), do: :map
  defp map_field_type(:datetime), do: :utc_datetime
  defp map_field_type(_), do: :string  # Default to string for unknown types
end
