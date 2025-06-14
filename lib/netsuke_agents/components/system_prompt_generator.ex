defmodule NetsukeAgents.Components.SystemPromptContextProvider do
  @moduledoc """
  Behaviour for system prompt context providers.
  """

  @callback get_info() :: String.t()

  @type t :: %{
          title: String.t(),
          provider: module()
        }

  defmacro __using__(_opts) do
    quote do
      @behaviour NetsukeAgents.Components.SystemPromptContextProvider
    end
  end
end

defmodule NetsukeAgents.Components.SystemPromptGenerator do
  @moduledoc """
  Generates system prompts for agents based on their configuration.
  """

  alias NetsukeAgents.Components.SystemPromptContextProvider

  @type t :: %__MODULE__{
          background: [String.t()],
          steps: [String.t()],
          output_instructions: [String.t()],
          context_providers: %{optional(String.t()) => SystemPromptContextProvider.t()}
        }

  defstruct background: ["This is a conversation with a helpful and friendly AI assistant."],
            steps: [],
            output_instructions: [
              "Always respond using the proper JSON schema.", # TODO: Should I set the responses to be JSON schema rather than native Elixir map?
              "Always use the available additional information and context to enhance the response."
            ],
            context_providers: %{}

  @doc """
  Creates a new SystemPromptGenerator with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      background: Keyword.get(opts, :background, ["This is a conversation with a helpful and friendly AI assistant."]),
      steps: Keyword.get(opts, :steps, []),
      output_instructions: Keyword.get(
        opts,
        :output_instructions,
        [
          "Always respond using the proper JSON schema.",
          "Always use the available additional information and context to enhance the response."
        ]
      ),
      context_providers: Keyword.get(opts, :context_providers, %{})
    }
  end

  @doc """
  Generates a prompt from the generator's configuration.
  """
  @spec generate_prompt(t()) :: String.t()
  def generate_prompt(%__MODULE__{} = generator) do
    sections = [
      {"IDENTITY and PURPOSE", generator.background},
      {"INTERNAL ASSISTANT STEPS", generator.steps},
      {"OUTPUT INSTRUCTIONS", generator.output_instructions}
    ]

    prompt_parts =
      Enum.flat_map(sections, fn {title, content} ->
        if Enum.empty?(content) do
          []
        else
          [
            "# #{title}",
            Enum.map(content, fn item -> "- #{item}" end),
            ""
          ]
        end
      end)
      |> List.flatten()

    context_parts =
      if map_size(generator.context_providers) > 0 do
        [
          "# EXTRA INFORMATION AND CONTEXT",
          Enum.flat_map(generator.context_providers, fn {_key, provider} ->
            module = provider.provider
            info = apply(module, :get_info, [])

            if info && String.trim(info) != "" do
              [
                "## #{provider.title}",
                info,
                ""
              ]
            else
              []
            end
          end)
        ]
        |> List.flatten()
      else
        []
      end

    (prompt_parts ++ context_parts)
    |> Enum.join("\n")
    |> String.trim()
  end
end
