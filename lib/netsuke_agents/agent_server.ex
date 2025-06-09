defmodule NetsukeAgents.AgentServer do
  use GenServer
  alias NetsukeAgents.{AgentEvent, Repo}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts[:agent_id]))
  end

  defp via(agent_id), do: {:via, Registry, {NetsukeAgents.AgentRegistry, agent_id}}

  def init(opts) do
    {:ok, %{agent_id: opts[:agent_id], memory: %{}}}
  end

  def run(agent_id, input) do
    GenServer.call(via(agent_id), {:run, input})
  end

  def handle_call({:run, input}, _from, state) do
    # Agent logic placeholder
    output = %{message: "Response to #{input}"}

    # Log event
    %AgentEvent{}
    |> AgentEvent.changeset(%{
      agent_id: state.agent_id,
      type: "response_generated",
      data: %{input: input, output: output},
      caused_by: "run_call"
    })
    |> Repo.insert()

    {:reply, output, state}
  end
end
