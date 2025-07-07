defmodule BaseAgentConfigTest do
  use ExUnit.Case
  # doctest NetsukeAgents

  import NetsukeAgents.AgentsFixtures

  alias NetsukeAgents.Factories.SchemaFactory
  alias NetsukeAgents.{BaseAgentConfig, AgentMemory}

  test "creates a simple schema from Ecto types" do
    assert SchemaFactory.create_schema(%{ingredients: :list, steps: :list})
  end

  test "creates an embedded schema from Ecto types" do
    assert SchemaFactory.create_schema(%{
        name: :string,
        items: {:array, {:embeds_many, %{name: :string, quantity: :integer}}}
      })
  end

  test "creates a new BaseAgentConfig with valid attributes" do

    valid_attrs = valid_config_attributes()
    valid_config = base_agent_config_fixture()
    base_agent_config = BaseAgentConfig.new(valid_attrs)

    assert valid_config == base_agent_config
  end

  test "creating a BaseAgentConfig without input_schema and output_schema assigns default schemas" do
      valid_attrs = valid_config_attributes(%{input_schema: nil, output_schema: nil})
      config = BaseAgentConfig.new(valid_attrs)

      assert config.input_schema == NetsukeAgents.DefaultInputSchema
      assert config.output_schema == NetsukeAgents.DefaultOutputSchema
  end

  test "creates a BaseAgentConfig with a Ecto types as output_schema" do
    schema = %{response: :string}
    valid_attrs = valid_config_attributes(%{output_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    assert config.output_schema == SchemaFactory.create_schema(schema)
  end

  test "creates a BaseAgentConfig with a map as output_schema" do
    schema = %{"response" => "string"}
    valid_attrs = valid_config_attributes(%{output_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    assert config.output_schema == SchemaFactory.create_schema(schema)
  end

  test "creates a BaseAgentConfig with an embedded map as output_schema" do
    schema = %{
      dish_name: "string",
      ingredients: %{
        "type" => "array",
        "items" => %{
          "type" => "embeds_many",
          "schema" => %{
            "ingredient_name" => "string",
            "ingredient_amount" => "integer"
          }
        }
      }
    }
    valid_attrs = valid_config_attributes(%{output_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    # The normalized schema should be a map that SchemaFactory can handle
    expected_schema_map = %{dish_name: :string, ingredients: %{items: {:array, {:embeds_many, %{ingredient_name: :string, ingredient_amount: :integer}}}}}

    assert config.output_schema == SchemaFactory.create_schema(expected_schema_map)
  end

  test "fails to creates a BaseAgentConfig with an invalid embedded map as output_schema" do
    schema = %{
      dish_name: "string",
      ingredients_list: %{
        "type" => "array",
        "items" => %{
          "type" => "wrong_type",
          "schema" => %{
            "ingredient_name" => "string",
            "ingredient_amount" => "integer"
          }
        }
      }
    }
    valid_attrs = valid_config_attributes(%{output_schema: schema})

    assert_raise ArgumentError, ~r/unknown type :wrong_type for field :ingredients/, fn ->
      BaseAgentConfig.new(valid_attrs)
    end
  end

  test "creates a BaseAgentConfig with a Ecto types as input_schema" do
    schema = %{question: :string}
    valid_attrs = valid_config_attributes(%{input_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    assert config.input_schema == SchemaFactory.create_schema(schema)
  end

  test "creates a BaseAgentConfig with a map as input_schema" do
    schema = %{"question" => "string"}
    valid_attrs = valid_config_attributes(%{input_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    assert config.input_schema == SchemaFactory.create_schema(schema)
  end

  test "creates a BaseAgentConfig with an embedded map as input_schema" do
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
    valid_attrs = valid_config_attributes(%{input_schema: schema})
    config = BaseAgentConfig.new(valid_attrs)

    # The normalized schema should be a map that SchemaFactory can handle
    expected_schema_map = %{items: {:array, {:embeds_many, %{name: :string, count: :integer}}}}

    assert config.input_schema == SchemaFactory.create_schema(expected_schema_map)
  end

  test "creates a BaseAgentConfig with multi-field string input schema like consuming app" do
    # Test the exact schema format from the consuming app
    input_schema = %{
      "keyword" => "string",
      "language" => "string",
      "mode" => "string"
    }

    valid_attrs = valid_config_attributes(%{input_schema: input_schema})
    config = BaseAgentConfig.new(valid_attrs)

    # Verify the schema was properly converted
    expected_schema_map = %{keyword: :string, language: :string, mode: :string}
    assert config.input_schema == SchemaFactory.create_schema(expected_schema_map)
  end

  test "creates a BaseAgentConfig with multi-field output schema including map type" do
    # Test the exact schema format from the consuming app
    output_schema = %{
      "content" => "string",
      "meta_description" => "string",
      "outline" => "map",
      "title" => "string"
    }

    valid_attrs = valid_config_attributes(%{output_schema: output_schema})
    config = BaseAgentConfig.new(valid_attrs)

    # Verify the schema was properly converted
    expected_schema_map = %{content: :string, meta_description: :string, outline: :map, title: :string}
    assert config.output_schema == SchemaFactory.create_schema(expected_schema_map)
  end

  test "creates a BaseAgentConfig with both input and output schemas from consuming app format" do
    input_schema = %{
      "keyword" => "string",
      "language" => "string",
      "mode" => "string"
    }

    output_schema = %{
      "content" => "string",
      "meta_description" => "string",
      "outline" => "map",
      "title" => "string"
    }

    valid_attrs = valid_config_attributes(%{
      input_schema: input_schema,
      output_schema: output_schema
    })
    config = BaseAgentConfig.new(valid_attrs)

    # Verify both schemas were properly converted
    expected_input_map = %{keyword: :string, language: :string, mode: :string}
    expected_output_map = %{content: :string, meta_description: :string, outline: :map, title: :string}

    assert config.input_schema == SchemaFactory.create_schema(expected_input_map)
    assert config.output_schema == SchemaFactory.create_schema(expected_output_map)
  end

  test "creates BaseAgentConfig with keyword list like consuming app init_agent function" do
    # Simulate the exact pattern from the consuming app
    input_schema = %{
      "keyword" => "string",
      "language" => "string",
      "mode" => "string"
    }

    output_schema = %{
      "content" => "string",
      "meta_description" => "string",
      "outline" => "map",
      "title" => "string"
    }

    # This mimics how BaseAgentConfig.new is called in the consuming app
    config = BaseAgentConfig.new([
      model: "gpt-4o-mini",
      memory: AgentMemory.new(),
      input_schema: input_schema,
      output_schema: output_schema,
      system_prompt_generator: nil
    ])

    # Verify the config was created correctly
    assert config.model == "gpt-4o-mini"
    assert config.input_schema != NetsukeAgents.DefaultInputSchema
    assert config.output_schema != NetsukeAgents.DefaultOutputSchema

    # Verify schemas were properly converted from string keys to atom keys
    expected_input_map = %{keyword: :string, language: :string, mode: :string}
    expected_output_map = %{content: :string, meta_description: :string, outline: :map, title: :string}

    assert config.input_schema == SchemaFactory.create_schema(expected_input_map)
    assert config.output_schema == SchemaFactory.create_schema(expected_output_map)
  end

  test "creates BaseAgentConfig with valid atom key map memory" do
    initial_memory =
      AgentMemory.new()
      |> then(fn mem ->
        AgentMemory.add_message(mem, "assistant", %{reply: "Hello! Anon-san How can I assist you today?"})
      end)
    valid_attrs = valid_config_attributes(%{memory: initial_memory})
    assert BaseAgentConfig.new(valid_attrs)
  end

  test "creates BaseAgentConfig with valid string key map memory" do
    initial_memory =
      AgentMemory.new()
      |> then(fn mem ->
        AgentMemory.add_message(mem, "assistant", %{"reply" => "Hello! Anon-san How can I assist you today?"})
      end)
    valid_attrs = valid_config_attributes(%{memory: initial_memory})
    assert BaseAgentConfig.new(valid_attrs)
  end
end
