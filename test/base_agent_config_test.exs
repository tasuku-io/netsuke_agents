defmodule BaseAgentConfigTest do
  use ExUnit.Case
  # doctest NetsukeAgents

  alias NetsukeAgents.Factories.SchemaFactory
  alias NetsukeAgents.BaseAgentConfig

  test "creates a simple schema from Ecto types" do
    assert SchemaFactory.create_schema(%{ingredients: :list, steps: :list})
  end

  test "creates an embedded schema from Ecto types" do
    assert SchemaFactory.create_schema(%{
        name: :string,
        items: {:array, {:embeds_many, %{name: :string, quantity: :integer}}}
      })
  end

  test "creates a BaseAgentConfig with a map as output_schema" do
    schema = %{"response" => "string"}
    config = BaseAgentConfig.new([output_schema: schema])

    assert config.output_schema == SchemaFactory.create_schema(schema)
  end

  test "creates a BaseAgentConfig with an embedded map as output_schema" do
    schema = %{
      "type" => "array",
      "items" => %{
        "type" => "embeds_many",
        "schema" => %{
          "name" => "string",
          "count" => "integer"
        }
      }
    }

    config = BaseAgentConfig.new([output_schema: schema])

    # The normalized schema should be a map that SchemaFactory can handle
    expected_schema_map = %{items: {:array, {:embeds_many, %{name: :string, count: :integer}}}}

    assert config.output_schema == SchemaFactory.create_schema(expected_schema_map)
  end
end
