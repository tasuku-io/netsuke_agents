defmodule SystemPromptGeneratorTest do
  use ExUnit.Case
  doctest NetsukeAgents.Components.SystemPromptGenerator

  alias NetsukeAgents.Components.{SystemPromptGenerator, SystemPromptContextProvider}

  # Test context provider modules
  defmodule TestContextProvider do
    use SystemPromptContextProvider

    @impl true
    def get_info do
      "This is test context information."
    end
  end

  defmodule EmptyContextProvider do
    use SystemPromptContextProvider

    @impl true
    def get_info do
      ""
    end
  end

  defmodule NilContextProvider do
    use SystemPromptContextProvider

    @impl true
    def get_info do
      nil
    end
  end

  describe "SystemPromptContextProvider" do
    test "defines a behaviour with get_info callback" do
      assert function_exported?(SystemPromptContextProvider, :behaviour_info, 1)
      callbacks = SystemPromptContextProvider.behaviour_info(:callbacks)
      assert {:get_info, 0} in callbacks
    end

    test "using the behaviour adds the behaviour to the module" do
      behaviours = TestContextProvider.module_info(:attributes)[:behaviour] || []
      assert SystemPromptContextProvider in behaviours
    end
  end

  describe "SystemPromptGenerator.new/1" do
    test "creates a new generator with default values" do
      generator = SystemPromptGenerator.new()

      assert generator.background == ["This is a conversation with a helpful and friendly AI assistant."]
      assert generator.steps == []
      assert generator.output_instructions == [
        "Always respond using the proper JSON schema.",
        "Always use the available additional information and context to enhance the response."
      ]
      assert generator.context_providers == %{}
    end

    test "creates a generator with custom background" do
      background = ["You are a helpful assistant.", "You specialize in coding."]
      generator = SystemPromptGenerator.new(background: background)

      assert generator.background == background
    end

    test "creates a generator with custom steps" do
      steps = ["Step 1: Analyze the request", "Step 2: Generate response"]
      generator = SystemPromptGenerator.new(steps: steps)

      assert generator.steps == steps
    end

    test "creates a generator with custom output instructions" do
      output_instructions = ["Be concise", "Use examples"]
      generator = SystemPromptGenerator.new(output_instructions: output_instructions)

      assert generator.output_instructions == output_instructions
    end

    test "creates a generator with context providers" do
      context_providers = %{
        "test" => %{title: "Test Provider", provider: TestContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)

      assert generator.context_providers == context_providers
    end

    test "creates a generator with all custom options" do
      opts = [
        background: ["Custom background"],
        steps: ["Custom step"],
        output_instructions: ["Custom instruction"],
        context_providers: %{"test" => %{title: "Test", provider: TestContextProvider}}
      ]
      generator = SystemPromptGenerator.new(opts)

      assert generator.background == ["Custom background"]
      assert generator.steps == ["Custom step"]
      assert generator.output_instructions == ["Custom instruction"]
      assert generator.context_providers == %{"test" => %{title: "Test", provider: TestContextProvider}}
    end
  end

  describe "SystemPromptGenerator.generate_prompt/1" do
    test "generates a basic prompt with default values" do
      generator = SystemPromptGenerator.new()
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# IDENTITY and PURPOSE")
      assert String.contains?(prompt, "- This is a conversation with a helpful and friendly AI assistant.")
      assert String.contains?(prompt, "# OUTPUT INSTRUCTIONS")
      assert String.contains?(prompt, "- Always respond using the proper JSON schema.")
      assert String.contains?(prompt, "- Always use the available additional information and context to enhance the response.")
      refute String.contains?(prompt, "# INTERNAL ASSISTANT STEPS")
      refute String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
    end

    test "generates prompt with custom background" do
      generator = SystemPromptGenerator.new(
        background: ["You are a coding assistant.", "You help with Elixir programming."]
      )
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "- You are a coding assistant.")
      assert String.contains?(prompt, "- You help with Elixir programming.")
    end

    test "generates prompt with steps when provided" do
      generator = SystemPromptGenerator.new(
        steps: ["Analyze the code", "Suggest improvements", "Provide examples"]
      )
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# INTERNAL ASSISTANT STEPS")
      assert String.contains?(prompt, "- Analyze the code")
      assert String.contains?(prompt, "- Suggest improvements")
      assert String.contains?(prompt, "- Provide examples")
    end

    test "skips empty sections" do
      generator = SystemPromptGenerator.new(
        background: ["Background info"],
        steps: [],
        output_instructions: ["Output info"]
      )
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# IDENTITY and PURPOSE")
      assert String.contains?(prompt, "# OUTPUT INSTRUCTIONS")
      refute String.contains?(prompt, "# INTERNAL ASSISTANT STEPS")
    end

    test "generates prompt with context providers" do
      context_providers = %{
        "test_provider" => %{title: "Test Information", provider: TestContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
      assert String.contains?(prompt, "## Test Information")
      assert String.contains?(prompt, "This is test context information.")
    end

    test "handles multiple context providers" do
      context_providers = %{
        "provider1" => %{title: "First Provider", provider: TestContextProvider},
        "provider2" => %{title: "Second Provider", provider: TestContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
      assert String.contains?(prompt, "## First Provider")
      assert String.contains?(prompt, "## Second Provider")
      # Should contain the info twice since both providers return the same text
      assert String.contains?(prompt, "This is test context information.")
    end

    test "skips context providers that return empty strings" do
      context_providers = %{
        "empty_provider" => %{title: "Empty Provider", provider: EmptyContextProvider},
        "valid_provider" => %{title: "Valid Provider", provider: TestContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
      assert String.contains?(prompt, "## Valid Provider")
      assert String.contains?(prompt, "This is test context information.")
      refute String.contains?(prompt, "## Empty Provider")
    end

    test "skips context providers that return nil" do
      context_providers = %{
        "nil_provider" => %{title: "Nil Provider", provider: NilContextProvider},
        "valid_provider" => %{title: "Valid Provider", provider: TestContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)
      prompt = SystemPromptGenerator.generate_prompt(generator)

      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
      assert String.contains?(prompt, "## Valid Provider")
      assert String.contains?(prompt, "This is test context information.")
      refute String.contains?(prompt, "## Nil Provider")
    end

    test "includes context section header even when all providers are empty" do
      # Note: This test documents the current behavior. The implementation could be improved
      # to skip the entire context section when all providers return empty content.
      context_providers = %{
        "empty_provider" => %{title: "Empty Provider", provider: EmptyContextProvider},
        "nil_provider" => %{title: "Nil Provider", provider: NilContextProvider}
      }
      generator = SystemPromptGenerator.new(context_providers: context_providers)
      prompt = SystemPromptGenerator.generate_prompt(generator)

      # Currently, the header is included even when no content follows
      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")
      refute String.contains?(prompt, "## Empty Provider")
      refute String.contains?(prompt, "## Nil Provider")
    end

    test "generates complete prompt with all sections" do
      context_providers = %{
        "test_provider" => %{title: "API Information", provider: TestContextProvider}
      }
      
      generator = SystemPromptGenerator.new(
        background: ["You are an API helper", "You assist with API integrations"],
        steps: ["Read the request", "Check available APIs", "Generate response"],
        output_instructions: ["Use JSON format", "Include error handling"],
        context_providers: context_providers
      )
      
      prompt = SystemPromptGenerator.generate_prompt(generator)

      # Check all main sections are present
      assert String.contains?(prompt, "# IDENTITY and PURPOSE")
      assert String.contains?(prompt, "# INTERNAL ASSISTANT STEPS")
      assert String.contains?(prompt, "# OUTPUT INSTRUCTIONS")
      assert String.contains?(prompt, "# EXTRA INFORMATION AND CONTEXT")

      # Check content is present
      assert String.contains?(prompt, "- You are an API helper")
      assert String.contains?(prompt, "- Read the request")
      assert String.contains?(prompt, "- Use JSON format")
      assert String.contains?(prompt, "## API Information")
      assert String.contains?(prompt, "This is test context information.")
    end

    test "trims whitespace from final prompt" do
      generator = SystemPromptGenerator.new(background: ["Test"])
      prompt = SystemPromptGenerator.generate_prompt(generator)

      # Should not start or end with whitespace
      assert prompt == String.trim(prompt)
    end

    test "handles prompt sections in correct order" do
      context_providers = %{
        "test_provider" => %{title: "Test Info", provider: TestContextProvider}
      }
      
      generator = SystemPromptGenerator.new(
        background: ["Background"],
        steps: ["Step 1"],
        output_instructions: ["Output"],
        context_providers: context_providers
      )
      
      prompt = SystemPromptGenerator.generate_prompt(generator)
      
      # Split into lines and find line numbers for each section
      lines = String.split(prompt, "\n")
      
      identity_line = Enum.find_index(lines, &String.contains?(&1, "# IDENTITY and PURPOSE"))
      steps_line = Enum.find_index(lines, &String.contains?(&1, "# INTERNAL ASSISTANT STEPS"))
      output_line = Enum.find_index(lines, &String.contains?(&1, "# OUTPUT INSTRUCTIONS"))
      context_line = Enum.find_index(lines, &String.contains?(&1, "# EXTRA INFORMATION AND CONTEXT"))

      # Verify order
      assert identity_line < steps_line
      assert steps_line < output_line
      assert output_line < context_line
    end
  end

  describe "SystemPromptContextProvider type" do
    test "type definition includes title and provider fields" do
      # This is more of a compile-time check, but we can verify the struct works
      provider_info = %{title: "Test Title", provider: TestContextProvider}
      
      assert provider_info.title == "Test Title"
      assert provider_info.provider == TestContextProvider
    end
  end
end
