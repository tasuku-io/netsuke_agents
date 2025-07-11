# Ensure application and dependencies are started
# Application.ensure_all_started(:logger)
# Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Agent Console ===
Type your messages below.
Type '/exit' to quit.
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}
alias NetsukeAgents.Components.SystemPromptGenerator

# Set up initial memory for agent
initial_memory =
  AgentMemory.new()
  |> AgentMemory.add_message("assistant", %{
    reply: "Hello! I am an expert Lua programmer. I can design programs to execute in a safe environment."
  })

custom_system_prompt = SystemPromptGenerator.new(
    background: [
      "You are a Lua Task Builder agent.",
      "Your job is to generate a Lua function named `run(context)` that can be safely executed in a sandboxed environment.",
      "You also generate a corresponding Elixir map (`context`) that will be converted into a Lua table and passed into the `run` function.",
      "Your Lua code will be executed using the Luerl runtime, which does not support unsafe global operations.",
      "The environment supports dynamic tool calls that allow safe access to external functionality.",
      "Linked in access token is abcdef"
    ],
    steps: [
      "Read and understand the instruction provided by the user.",
      "Generate Lua code with a single function named `run(context)`. This function must accept and return the `context` table.",
      "Use only safe Lua syntax and standard table, string, math operations. Avoid any global functions like `os`, `io`, `debug`, or `_G`.",
      "You can use the following SAFE tool calls in your Lua code:",
      "  - `http.get(url)` or `http.get(url, config)` - Make HTTP GET requests to external APIs",
      "  - `json.decode(json_string)` - Parse JSON strings into Lua tables",
      "These tool calls are automatically intercepted and executed safely by the Elixir runtime.",
      "Ensure the function performs the behavior requested by the user using values from the provided `context`.",
      "Create a context map containing all fields that will be accessed or mutated in your Lua code.",
      "Make sure your context map uses only string keys and simple values (numbers, booleans, strings, lists, maps).",
      "Always return your result as a map with two keys: `lua_code` and `context`."
    ],
    output_instructions: [
      "Your output must be a valid Elixir map with this schema: `%{lua_code: string, context: map}`.",
      "The `lua_code` string must define `function run(context)` and return the modified context.",
      "The `context` must be a flat or nested map, ready to be serialized to a Lua table.",
      "Do not include any explanatory text, comments, or extra formatting—only the strict output data structure.",
      "All Lua code must use simple, safe expressions. Do not use any metaprogramming or access globals.",
      "When using tool calls like `http.get()`, `json.decode()`, or `json.encode()`, use them directly in your Lua code.",
      "Tool calls will be automatically intercepted and safely executed by the runtime environment.",
      "Validate that your generated context includes all variables used in the Lua function.",
      "The value of `lua_code` must be returned as a triple-quoted Elixir string using ~S\"\"\"...\"\"\" to preserve line breaks."
    ]
  )

# Create config for the agent
config = BaseAgentConfig.new([
  memory: initial_memory,
  output_schema: %{
    lua_code: :string,
    context: :map
  },
  system_prompt_generator: custom_system_prompt
])

# Initialize the agent
agent = BaseAgent.new("console-agent", config)

# Show initial system prompt and message
IO.puts("🧠 Agent: Hello! Anon-san How can I assist you today?")

# Chat loop
loop = fn loop, agent ->
  user_input = IO.gets("> ") |> String.trim()

  if user_input in ["/exit", "/quit"] do
    IO.puts("Exiting chat...")
  else
    input = %{chat_message: user_input} # Validate against input schema
    {:ok, updated_agent, response} = BaseAgent.run(agent, input)

    IO.puts("🤖 Context:")
    IO.inspect(response.context)
    IO.puts("🤖 Lua Code: \n#{response.lua_code}")
    loop.(loop, updated_agent)
  end
end

# Perform a call to the endpoint GET https://api.linkedin.com/v2/userinfo to obtain the field "name" passing the header Authorization: Bearer <access token>

# generate a function to call the pokeapi enpoint GET https://pokeapi.co/api/v2/pokemon/bulbasaur/ and returns the id from the response

loop.(loop, agent)
