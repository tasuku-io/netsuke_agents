defmodule NetsukeAgents.BaseAgentConfig do
  @moduledoc """
  Configuration struct for initializing a BaseAgent.
  """

  alias NetsukeAgents.AgentMemory
  alias NetsukeAgents.Schemas.BaseIOSchema

  defstruct [
    :client,
    model: "gpt-4o-mini",
    memory: nil,
    # system_prompt_generator: nil, # TODO: Implement system prompt generator
    system_role: "system",
    input_schema: BaseIOSchema,
    output_schema: BaseIOSchema,
    model_api_parameters: nil
  ]

  @type t :: %__MODULE__{
          client: any(), # Replace with actual client type later
          model: String.t(),
          memory: AgentMemory.t() | nil,
          system_role: String.t(),
          input_schema: module(),
          output_schema: module(),
          model_api_parameters: map() | nil
        }
end
