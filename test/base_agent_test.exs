defmodule BaseAgentTest do
  use ExUnit.Case
  # doctest NetsukeAgents

  import NetsukeAgents.AgentsFixtures

  alias NetsukeAgents.BaseAgent

  test "creates a new BaseAgent with a valid configuration" do
    config = base_agent_config_fixture()
    agent = base_agent_fixture("some_id")

    assert BaseAgent.new("some_id", config) === agent
  end

  test "validates input against schema" do
    input_schema = %{"question" => "string"}

    valid_attrs = valid_config_attributes(%{input_schema: input_schema})
    agent = base_agent_fixture("some_id", valid_attrs)

    input = %{"question" => "What is the capital of Mexico?"}

    assert :ok == BaseAgent.validate_input_against_schema!(input, agent.input_schema)
  end

  describe "validate_input_against_schema!/2" do
    test "validates valid input against DefaultInputSchema" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      valid_input = %{chat_message: "Hello, how are you?"}

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input, agent.input_schema)
    end

    test "raises ArgumentError for missing required fields" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      invalid_input = %{}

      assert_raise ArgumentError, ~r/Input validation failed.*chat_message.*can't be blank/, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end
    end

    test "raises ArgumentError for nil required fields" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      invalid_input = %{chat_message: nil}

      assert_raise ArgumentError, ~r/Input validation failed.*chat_message.*can't be blank/, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end
    end

    test "raises ArgumentError for empty string required fields" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      invalid_input = %{chat_message: ""}

      assert_raise ArgumentError, ~r/Input validation failed.*chat_message.*can't be blank/, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end
    end

    test "validates input against custom schema with multiple fields" do
      custom_schema = %{
        "name" => "string",
        "age" => "integer",
        "email" => "string"
      }

      config = base_agent_config_fixture(%{input_schema: custom_schema})
      agent = BaseAgent.new("test_agent", config)

      valid_input = %{
        name: "John Doe",
        age: 30,
        email: "john@example.com"
      }

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input, agent.input_schema)
    end

    test "raises ArgumentError with detailed field errors for custom schema" do
      custom_schema = %{
        "name" => "string",
        "age" => "integer"
      }

      config = base_agent_config_fixture(%{input_schema: custom_schema})
      agent = BaseAgent.new("test_agent", config)

      invalid_input = %{age: "not_an_integer"}  # missing name, invalid age type

      error_message = assert_raise ArgumentError, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end

      # Should contain information about both validation errors
      assert error_message.message =~ "Input validation failed"
    end

    test "raises ArgumentError with detailed field errors for custom embedded schema" do
      # Use the direct format that SchemaFactory expects
      custom_schema = %{
        "recipe_items" => {:array, {:embeds_many, %{
          "ingredient_name" => "string",
          "ingredient_amount" => "integer"
        }}}
      }

      config = base_agent_config_fixture(%{input_schema: custom_schema})
      agent = BaseAgent.new("test_agent", config)

      # Use proper structure for embedded schema: recipe_items should be a list of embeds
      invalid_input = %{recipe_items: [%{ingredient_amount: "not_an_integer"}]}  # missing name, invalid amount type

      error_message = assert_raise ArgumentError, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end

      # Should contain information about both validation errors
      assert error_message.message =~ "Input validation failed"
      assert error_message.message =~ "ingredient_name: can't be blank"
      assert error_message.message =~ "ingredient_amount: is invalid"
    end

    test "accepts atom keys in input" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      valid_input_with_atoms = %{chat_message: "Hello with atom keys"}

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input_with_atoms, agent.input_schema)
    end

    test "accepts string keys in input" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      valid_input_with_strings = %{"chat_message" => "Hello with string keys"}

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input_with_strings, agent.input_schema)
    end

    test "validates against OutputSchema as well" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      valid_output = %{reply: "This is a valid reply"}

      assert :ok == BaseAgent.validate_input_against_schema!(valid_output, agent.output_schema)
    end

    test "raises for invalid OutputSchema" do
      config = base_agent_config_fixture()
      agent = BaseAgent.new("test_agent", config)

      invalid_output = %{wrong_field: "This should fail"}

      assert_raise ArgumentError, ~r/Input validation failed.*reply.*can't be blank/, fn ->
        BaseAgent.validate_input_against_schema!(invalid_output, agent.output_schema)
      end
    end

    test "creates BaseAgent with multi-field string input schema from consuming app format" do
      input_schema = %{
        "keyword" => "string",
        "language" => "string",
        "mode" => "string"
      }

      config = base_agent_config_fixture(%{input_schema: input_schema})
      agent = BaseAgent.new("test_agent", config)

      # Test valid input
      valid_input = %{
        keyword: "elixir programming",
        language: "en",
        mode: "tutorial"
      }

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input, agent.input_schema)
    end

    test "validates input against multi-field string schema from consuming app with string keys" do
      input_schema = %{
        "keyword" => "string",
        "language" => "string",
        "mode" => "string"
      }

      config = base_agent_config_fixture(%{input_schema: input_schema})
      agent = BaseAgent.new("test_agent", config)

      # Test with string keys (common when data comes from JSON/database)
      valid_input_string_keys = %{
        "keyword" => "elixir programming",
        "language" => "en",
        "mode" => "tutorial"
      }

      assert :ok == BaseAgent.validate_input_against_schema!(valid_input_string_keys, agent.input_schema)
    end

    test "raises ArgumentError for missing fields in multi-field string schema" do
      input_schema = %{
        "keyword" => "string",
        "language" => "string",
        "mode" => "string"
      }

      config = base_agent_config_fixture(%{input_schema: input_schema})
      agent = BaseAgent.new("test_agent", config)

      # Missing required fields
      invalid_input = %{keyword: "elixir programming"}  # missing language and mode

      error_message = assert_raise ArgumentError, fn ->
        BaseAgent.validate_input_against_schema!(invalid_input, agent.input_schema)
      end

      assert error_message.message =~ "Input validation failed"
      assert error_message.message =~ "language: can't be blank"
      assert error_message.message =~ "mode: can't be blank"
    end

    test "validates output against multi-field output schema including map type" do
      output_schema = %{
        "content" => "string",
        "meta_description" => "string",
        "outline" => "map",
        "title" => "string"
      }

      config = base_agent_config_fixture(%{output_schema: output_schema})
      agent = BaseAgent.new("test_agent", config)

      valid_output = %{
        content: "This is the main content of the article...",
        meta_description: "A brief description for SEO",
        outline: %{introduction: "intro text", body: "main content", conclusion: "wrap up"},
        title: "How to Learn Elixir"
      }

      assert :ok == BaseAgent.validate_input_against_schema!(valid_output, agent.output_schema)
    end

    test "raises ArgumentError for invalid output in multi-field schema" do
      output_schema = %{
        "content" => "string",
        "meta_description" => "string",
        "outline" => "map",
        "title" => "string"
      }

      config = base_agent_config_fixture(%{output_schema: output_schema})
      agent = BaseAgent.new("test_agent", config)

      # Missing required fields
      invalid_output = %{content: "Some content"}  # missing other required fields

      error_message = assert_raise ArgumentError, fn ->
        BaseAgent.validate_input_against_schema!(invalid_output, agent.output_schema)
      end

      assert error_message.message =~ "Input validation failed"
      assert error_message.message =~ "meta_description: can't be blank"
      assert error_message.message =~ "title: can't be blank"
    end
  end

  test "validates input agains embedded schema with Map format" do
    # This test ensures that the embedded schema with Map format is validated correctly
    embedded_schema = %{
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

    config = base_agent_config_fixture(%{input_schema: embedded_schema})
    agent = BaseAgent.new("test_embedded_schema", config)

    # Valid input with correct structure
    valid_input = %{dish_name: "okonomiyaki", ingredients: [%{ingredient_name: "Flour", ingredient_amount: 500}]}

    assert :ok == BaseAgent.validate_input_against_schema!(valid_input, agent.config.input_schema)

    # Invalid input missing required field
    invalid_input = %{dish_name: "okonomiyaki", ingredients: [%{ingredient_amount: 500}]}  # Missing ingredient_name

    error_message = assert_raise ArgumentError, fn ->
      BaseAgent.validate_input_against_schema!(invalid_input, agent.config.input_schema)
    end

    assert error_message.message =~ "Input validation failed"
    assert error_message.message =~ "ingredient_name: can't be blank"
  end

  test "validates input agains embedded schema with Ecto Types format" do
    # This test ensures that the embedded schema with Ecto Types format is validated correctly

    embedded_schema = %{
      dish_name: :string,
      ingredients: {
        :array, {
          :embeds_many, %{
            ingredient_name: :string,
            ingredient_amount: :integer
          }
        }
      }
    }

    config = base_agent_config_fixture(%{input_schema: embedded_schema})
    agent = BaseAgent.new("test_embedded_schema", config)

    # Valid input with correct structure
    valid_input = %{dish_name: "okonomiyaki", ingredients: [%{ingredient_name: "Flour", ingredient_amount: 500}]}

    assert :ok == BaseAgent.validate_input_against_schema!(valid_input, agent.config.input_schema)

    # Invalid input missing required field
    invalid_input = %{dish_name: "okonomiyaki", ingredients: [%{ingredient_amount: 500}]}  # Missing ingredient_name

    error_message = assert_raise ArgumentError, fn ->
      BaseAgent.validate_input_against_schema!(invalid_input, agent.config.input_schema)
    end

    assert error_message.message =~ "Input validation failed"
    assert error_message.message =~ "ingredient_name: can't be blank"
  end
end
