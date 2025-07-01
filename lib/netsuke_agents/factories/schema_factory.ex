defmodule NetsukeAgents.Factories.SchemaFactory do
  @moduledoc """
  Factory for dynamically generating Ecto schemas at runtime from simple map definitions.
  """

  @doc """
  Creates a dynamic schema module from a map of field definitions.

  ## Parameters
    * `field_map` - A map where keys are field names and values are field types

  ## Field Types
    * Any valid Ecto field type (e.g., `:string`, `:integer`, `:boolean`, `{:array, :string}`, etc.)
    * `:list` - Converted to `{:array, :string}` for backwards compatibility
    * `:datetime` - Converted to `:utc_datetime` for backwards compatibility
    * `{:array, {:embeds_many, schema_map}}` - Creates an embedded schema for array of structured maps

  ## Examples

      iex> SchemaFactory.create_schema(%{ingredients: :list, steps: :list})
      DynamicSchema_ingredients_steps

      iex> SchemaFactory.create_schema(%{
      ...>   name: :string,
      ...>   items: {:array, {:embeds_many, %{name: :string, quantity: :integer}}}
      ...> })
      DynamicSchema_items_name
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
      {fields_ast, embedded_schemas} = build_fields_with_embeds(field_map, module_name)

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

          # Define embedded schemas first
          unquote_splicing(embedded_schemas)

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

  # Helper function to build fields and handle embedded schemas
  defp build_fields_with_embeds(field_map, parent_module_name) do
    {fields, embeds} = Enum.reduce(field_map, {[], []}, fn {field_name, field_type}, {fields_acc, embeds_acc} ->
      case field_type do
        {:array, {:embeds_many, embed_schema}} when is_map(embed_schema) ->
          # Create embedded schema module
          embed_module_name = :"#{parent_module_name}_#{field_name}_Embed"
          embed_fields = for {embed_field_name, embed_field_type} <- embed_schema do
            actual_type = map_field_type(embed_field_type)
            quote do
              field unquote(embed_field_name), unquote(actual_type)
            end
          end

          embed_required_fields = Map.keys(embed_schema)

          # Define embedded schema module
          embed_ast = quote do
            defmodule unquote(embed_module_name) do
              use Ecto.Schema
              import Ecto.Changeset

              @primary_key false
              embedded_schema do
                unquote_splicing(embed_fields)
              end

              def changeset(embed, attrs) do
                embed
                |> cast(attrs, unquote(embed_required_fields))
                |> validate_required(unquote(embed_required_fields))
              end
            end
          end

          # Create embeds_many field
          field_ast = quote do
            embeds_many unquote(field_name), unquote(embed_module_name)
          end

          {[field_ast | fields_acc], [embed_ast | embeds_acc]}

        _ ->
          # Regular field
          actual_type = map_field_type(field_type)
          field_ast = quote do
            field unquote(field_name), unquote(actual_type)
          end
          {[field_ast | fields_acc], embeds_acc}
      end
    end)

    {Enum.reverse(fields), Enum.reverse(embeds)}
  end

  # Helper function to handle both simple type names and direct Ecto types
  defp map_field_type(:list), do: {:array, :string}  # Keep for backwards compatibility
  defp map_field_type(:datetime), do: :utc_datetime  # Keep for backwards compatibility
  defp map_field_type(type), do: type  # Pass through all other types directly
end
