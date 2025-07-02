defmodule NetsukeAgents.AgentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  and running Netsuke Agents.
  """

  alias NetsukeAgents.{BaseAgentConfig, BaseAgent, DefaultInputSchema, DefaultOutputSchema, AgentMemory}

  def valid_config_attributes(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      model: "gpt-4o-mini",
      memory: AgentMemory.new(),
      system_role: "system",
      input_schema: DefaultInputSchema,
      output_schema: DefaultOutputSchema,
      model_api_parameters: %{temperature: 0.7},
      system_prompt_generator: nil
    })
    |> Enum.into([])  # Convert map to keyword list
  end

  def base_agent_config_fixture(attrs \\ %{}) do
    config =
      attrs
      |> valid_config_attributes()
      |> BaseAgentConfig.new()

    config
  end

  def base_agent_fixture(id, attrs \\ %{}) do
    config = base_agent_config_fixture(attrs)
    if id == nil do
      # If no id is provided, generate a random one
      id = "agent_#{:rand.uniform(1000)}"
      BaseAgent.new(id, config)
    else
      # Use the provided id
      BaseAgent.new(id, config)
    end
  end
end
