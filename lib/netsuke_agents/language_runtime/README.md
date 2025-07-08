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
* Support calling other LLMs (inception) with safeguards.

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

### 3. Tool Bindings (via `NetsukeAgents.ToolRegistry`)

Each tool exposes a function in Lua with the following signature:

```lua
result = tool_name(params)
```

Where `params` is a Lua table.

Available tools:

* `query_db(params)` → List of maps
* `fetch_url(urls, batch)` → Map of URL to binary
* `send_email(to, subject, body, attachments)` → Delivery status
* `transform_data(input, template, format)` → String
* `call_llm(prompt)` → String (text output from external LLM)

All tools must:

* Be pure functions from input to output
* Return errors in predictable structure (e.g., `{error = "reason"}`)

### 4. Context as Memory

* Variables defined in Lua (e.g. `local x = ...`) serve as memory.
* The `context` table allows data to persist across executions or agents.
* Agent can read/write to context like:

```lua
context["users"] = query_db({...})
```

---

## Execution Flow

1. User sends a task to the system.
2. Planner agent returns a Lua function `run(context)` as string.
3. `LuaExecutor` loads the code in a new Luerl environment.
4. Tool functions are bound into the Lua environment.
5. `run(context)` is invoked with initial context.
6. Result is returned as an Elixir map.

---

## Safety Model

* No access to `os`, `io`, `require`, `load`, or system calls.
* All tool calls are namespaced and whitelisted.
* Execution time and memory can be bounded per run.
* Optional: Audit log of all inputs/outputs and tool invocations.

---

## Extensions (Future)

* Lua linting and static validation pre-run.
* Plan visualization as computation graph.
* Tool introspection: expose schema metadata to agent.
* Multi-agent workflows using `call_agent(name, context)`.
* Error propagation + step retries.

---

## Example Lua Plan

```lua
function run(context)
  local users = query_db({table = "users", where = "age > 30"})
  local urls = {}
  for i, user in ipairs(users) do
    table.insert(urls, user.profile_image_url)
  end

  local images = fetch_url(urls, true)
  local body = transform_data(users, "summary_email", "html")
  local receipt = send_email("admin@company.com", "User Summary", body, images)

  context["receipt"] = receipt
  return context
end
```

---

## Conclusion

This system treats agents as safe, intelligent code generators and executes their plans inside a deterministic Lua sandbox. It blends programmable autonomy with runtime safety and makes code the lingua franca for AI workflows.
