# 🧠 Netsuke Agents Luerl Runtime Specification

## Overview

This document defines the architecture and components of a secure, programmable agent execution system using the **Netsuke Agents** framework and **Luerl** (Lua interpreter for Erlang). This system treats agent plans as Lua programs that run inside a sandboxed environment, enabling safe, composable, and traceable execution.

---

## Goals

* Enable agents to emit Lua programs as execution plans.
* Provide a sandboxed execution environment via Luerl.
* Expose a limited set of safe, typed tools to Lua.
* Treat variables as memory and code as the execution graph.
* Allow chaining of tools, loops, and branching logic.
* Support calling external APIs with safeguards.

---

## System Components

### 1. Planner Agent

* Input: Natural language user prompt.
* Output: A Lua program string defining a function `run(context)`.
* Constraints:

  * Uses only exposed functions.
  * No access to Lua standard libraries beyond tables, strings, math.
  * Program must be deterministic and side-effect free (besides tools).

### 2. Luerl Sandbox Runtime (`NetsukeAgents.LuaExecutor`)

* Receives the Lua string from the planner.
* Preloads a Lua environment with safe tool bindings.
* Converts the Elixir context map into a Lua table.
* Calls `run(context)` inside the Luerl VM.
* Converts the returned Lua table back into Elixir.

### 3. Tool Bindings (via `NetsukeAgents.ToolRouter`)

Each tool exposes a function in Lua with the following signature:

```lua
result = tool_namespace.function_name(params)
```

**Currently Available Tools:**

* `http.get(url)` → Binary response body or error string
* `json.decode(json_string)` → Lua table or error string

**Security Features:**

* URL validation with allowlist of safe hosts
* JSON parsing with automatic data simplification
* Error handling returns descriptive strings instead of crashing
* All tool calls are logged and can be audited

### 4. Context as Memory

* Variables defined in Lua (e.g. `local x = ...`) serve as memory.
* The `context` table allows data to persist across executions or agents.
* Agent can read/write to context like:

```lua
context["users"] = http.get("https://api.example.com/users")
local data = json.decode(context["users"])
context["processed_data"] = data
```

---

## Execution Flow

1. User sends a task to the system.
2. Planner agent returns a Lua function `run(context)` as string.
3. `LuaExecutor.execute/3` creates a new sandboxed Luerl environment.
4. Tool functions are bound into the Lua environment via `ToolRouter`.
5. Input context is converted from Elixir map to Lua table.
6. `run(context)` is invoked with the converted context.
7. Result is converted back to Elixir map and returned.

---

## Safety Model

### Security Restrictions

* **No dangerous globals**: `os`, `io`, `require`, `load`, `dofile`, `loadfile`, `getfenv`, `setfenv`, `debug` are removed
* **No _G manipulation**: Direct and obfuscated access to global table is blocked
* **No metaprogramming**: `getmetatable`, `rawget` access patterns are restricted
* **Pattern detection**: Advanced regex patterns detect obfuscation attempts

### Runtime Limits

* **Execution timeout**: Default 30 seconds (configurable)
* **Memory limits**: Default 10MB (configurable)
* **Circular reference protection**: Automatic detection and handling
* **Host allowlist**: Only approved domains can be accessed via HTTP

### Validation

* **Program validation**: Checks for required `run()` function and dangerous patterns
* **URL validation**: Ensures only safe, allowed hosts are accessible
* **Data simplification**: Complex nested structures are automatically simplified

---

## Current Implementation Status

### ✅ Implemented Features

- [x] Secure Lua sandbox with Luerl
- [x] HTTP GET requests via `http.get()`
- [x] JSON parsing via `json.decode()`
- [x] Comprehensive security validation
- [x] Context conversion between Elixir and Lua
- [x] Timeout and memory limiting
- [x] Circular reference detection
- [x] URL allowlist security
- [x] Tool call error handling

### 🚧 Planned Extensions

- [ ] `json.encode(lua_table)` → JSON string
- [ ] Database query tools: `query_db(params)`
- [ ] Email sending: `send_email(to, subject, body, attachments)`
- [ ] Data transformation: `transform_data(input, template, format)`
- [ ] LLM integration: `call_llm(prompt)`
- [ ] Multi-agent workflows: `call_agent(name, context)`
- [ ] Plan visualization as computation graph
- [ ] Tool introspection with schema metadata

---

## Example Usage

### Basic HTTP + JSON Processing

```lua
function run(context)
  -- Fetch data from API
  local response = http.get("https://pokeapi.co/api/v2/pokemon/bulbasaur/")
  
  -- Parse JSON response
  local pokemon_data = json.decode(response)
  
  -- Extract specific fields
  context["pokemon_id"] = pokemon_data["id"]
  context["pokemon_name"] = pokemon_data["name"]
  context["pokemon_height"] = pokemon_data["height"]
  
  return context
end
```

### Agent Integration Example

```elixir
# Agent generates Lua code and context
response = %{
  lua_code: """
  function run(context)
    local response = http.get(context["api_url"])
    local data = json.decode(response)
    context["result"] = data[context["target_field"]]
    return context
  end
  """,
  context: %{
    "api_url" => "https://pokeapi.co/api/v2/pokemon/bulbasaur/",
    "target_field" => "id"
  }
}

# Execute in sandbox
{:ok, result} = LuaExecutor.execute(response.lua_code, response.context)
# => %{"api_url" => "...", "target_field" => "id", "result" => 1}
```

---

## API Reference

### `NetsukeAgents.LuaExecutor`

#### `execute(lua_code, context \\ %{}, opts \\ [])`

Executes Lua code in a sandboxed environment.

**Parameters:**
- `lua_code`: String containing Lua code with `run(context)` function
- `context`: Elixir map converted to Lua table
- `opts`: Keyword list with `:timeout` and `:memory_limit`

**Returns:**
- `{:ok, result_map}` on success
- `{:error, reason}` on failure

#### `validate_program(lua_code)`

Validates Lua code for security compliance.

**Returns:**
- `:ok` if safe
- `{:error, reason}` if dangerous patterns detected

### `NetsukeAgents.ToolRouter`

#### `http_get(url)`

Makes HTTP GET request to allowed URL.

#### `json_decode(json_string)`

Parses JSON with automatic data simplification.

---

## Security Considerations

### Allowed Hosts

Current allowlist includes testing APIs:
- `jsonplaceholder.typicode.com`
- `httpbin.org`
- `api.github.com`
- `pokeapi.co`
- `*.local` domains

### Data Simplification

JSON responses are automatically simplified to prevent:
- Circular references
- Overly complex nested structures
- Large arrays (>5 elements)
- Non-essential fields in objects

### Pattern Detection

The validator detects various security bypass attempts:
- Direct dangerous function calls
- `_G` table manipulation
- Variable-based obfuscation
- String concatenation attacks
- Metatable manipulation

---

## Conclusion

This system provides a secure, practical implementation for executing AI-generated Lua programs. It balances programmable autonomy with runtime safety, making it suitable for production use cases where agents need to interact with external APIs while maintaining security boundaries.

The current implementation focuses on HTTP/JSON workflows, with a clear path for extending to additional tool categories while maintaining the same security