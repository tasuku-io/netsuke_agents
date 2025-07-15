# Ensure application and dependencies are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:jason)

IO.puts("""
=== 🤖 Netsuke Lua Executor Agent Test ===
""")

alias NetsukeAgents.{BaseAgent, BaseAgentConfig, AgentMemory}
alias NetsukeAgents.Components.SystemPromptGenerator
alias NetsukeAgents.LuaExecutor

defmodule PokeapiDocsProvider do
  use NetsukeAgents.Components.SystemPromptContextProvider

  @impl true
  def get_info do
    """
    pokeapi base url: https://pokeapi.co/

    openapi: 3.1.0
    info:
    title: PokéAPI
    version: 2.7.0
    description: "All the Pokémon data you'll ever need in one place, easily accessible\
    \ through a modern free open-source RESTful API.\n\n## What is this?\n\nThis is\
    \ a full RESTful API linked to an extensive database detailing everything about\
    \ the Pokémon main game series.\n\nWe've covered everything from Pokémon to Berry\
    \ Flavors.\n\n## Where do I start?\n\nWe have awesome [documentation](https://pokeapi.co/docs/v2)\
    \ on how to use this API. It takes minutes to get started.\n\nThis API will always\
    \ be publicly available and will never require any extensive setup process to\
    \ consume.\n\nCreated by [**Paul Hallett**](https://github.com/phalt) and other\
    \ [**PokéAPI contributors***](https://github.com/PokeAPI/pokeapi#contributing)\
    \ around the world. Pokémon and Pokémon character names are trademarks of Nintendo.\n\
    \    "
    paths:
    /api/v2/pokemon/:
    get:
    operationId: api_v2_pokemon_list
    description: Pokémon are the creatures that inhabit the world of the Pokémon
    games. They can be caught using Pokéballs and trained by battling with other
    Pokémon. Each Pokémon belongs to a specific species but may take on a variant
    which makes it differ from other Pokémon of the same species, such as base
    stats, available abilities and typings. See [Bulbapedia](http://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_(species))
    for greater detail.
    summary: List pokemon
    parameters:
    - name: limit
    required: false
    in: query
    description: Number of results to return per page.
    schema:
    type: integer
    - name: offset
    required: false
    in: query
    description: The initial index from which to return the results.
    schema:
    type: integer
    - in: query
    name: q
    schema:
    type: string
    description: "> Only available locally and not at [pokeapi.co](https://pokeapi.co/docs/v2)\n\
    Case-insensitive query applied on the `name` property. "
    tags:
    - pokemon
    security:
    - cookieAuth: []
    - basicAuth: []
    - {}
    responses:
    '200':
    content:
    application/json:
    schema:
    $ref: '#/components/schemas/PaginatedPokemonSummaryList'
    description: ''
    /api/v2/pokemon/{id}/:
    get:
    operationId: api_v2_pokemon_retrieve
    description: Pokémon are the creatures that inhabit the world of the Pokémon
    games. They can be caught using Pokéballs and trained by battling with other
    Pokémon. Each Pokémon belongs to a specific species but may take on a variant
    which makes it differ from other Pokémon of the same species, such as base
    stats, available abilities and typings. See [Bulbapedia](http://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_(species))
    for greater detail.
    summary: Get pokemon
    parameters:
    - in: path
    name: id
    schema:
    type: string
    description: This parameter can be a string or an integer.
    required: true
    tags:
    - pokemon
    security:
    - cookieAuth: []
    - basicAuth: []
    - {}
    responses:
    '200':
    content:
    application/json:
    schema:
    $ref: '#/components/schemas/PokemonDetail'
    description: ''
    """
  end
end

defmodule PokemonInfoProvider do
  use NetsukeAgents.Components.SystemPromptContextProvider

  @impl true
  def get_info do # TODO: add pokeapi docs in context provider
    """
    Pokemon name to search: bulbasaur

    This pokemon name can be used to query the PokeAPI for information about the Pokemon.
    """
  end
end

# Set up initial memory for agent
agent_memory =
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
      "The environment supports dynamic tool calls that allow safe access to external functionality."
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
      "The value named response on your output should be a short description of the operation performed in a simple language for a non technical user.",
      "The value named operation on your output must be a valid Elixir map with this schema: `%{lua_code: string, context: map}`.",
      "The `lua_code` string must define `function run(context)` and return the modified context.",
      "The `context` must be a flat or nested map, ready to be serialized to a Lua table.",
      "Do not include any explanatory text, comments, or extra formatting—only the strict output data structure.",
      "All Lua code must use simple, safe expressions. Do not use any metaprogramming or access globals.",
      "When using tool calls like `http.get()`, `json.decode()`, or `json.encode()`, use them directly in your Lua code.",
      "Tool calls will be automatically intercepted and safely executed by the runtime environment.",
      "Validate that your generated context includes all variables used in the Lua function.",
      "The value of `lua_code` must be returned as a triple-quoted Elixir string using ~S\"\"\"...\"\"\" to preserve line breaks."
    ],
    context_providers: %{
      "pokeapi_docs" => %{
        title: "PokeAPI Documentation",
        provider: PokeapiDocsProvider
      },
      # "pokemon_name" => %{
      #   title: "Pokemon Name",
      #   provider: PokemonInfoProvider
      # }
    }
  )

# Create config for the agent
config = BaseAgentConfig.new([
  memory: agent_memory,
  output_schema: %{
    response: :string,
    operation: %{
      lua_code: :string,
      context: :map
    }
  },
  system_prompt_generator: custom_system_prompt
])

# Initialize agent
agent = BaseAgent.new("agent", config)

# Define single input
input = "Write a program that calls the pokeapi to fetch the id of bulbasaur."

IO.puts("\n=== Processing Query ===")
IO.puts("User: #{input}")

input = %{chat_message: input}
{:ok, _updated_agent, response} = BaseAgent.run(agent, input)

IO.inspect(response.response, label: "\nAgent Response Text")

{:ok, result} = LuaExecutor.execute(response.operation.lua_code, response.operation.context)

IO.inspect(result, label: "\Code Execution Result")

IO.puts("\n=== Processing completed ===")
