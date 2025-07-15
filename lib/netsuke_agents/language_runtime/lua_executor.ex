defmodule NetsukeAgents.LuaExecutor do
  @moduledoc """
  Provides a secure Lua execution environment using Luerl for running agent plans.

  This module creates a sandboxed Lua runtime where agents can execute generated
  Lua programs safely, with access only to whitelisted tools and functions.
  """

  require Logger

  @default_opts [
    timeout: 30_000,  # 30 seconds
    memory_limit: 10_000_000  # 10MB
  ]

  @doc """
  Executes a Lua program string in a sandboxed environment.

  ## Parameters
  - `lua_code`: String containing Lua code with a `run(context)` function
  - `context`: Elixir map that will be converted to Lua table and passed to run()
  - `opts`: Optional execution options (timeout, memory limits, etc.)

  ## Returns
  - `{:ok, result}` - Success with the returned context as Elixir map
  - `{:error, reason}` - Execution error or validation failure

  ## Example
      iex> lua_code = "function run(context) context.result = 'hello'; return context end"
      iex> LuaExecutor.execute(lua_code, %{input: "test"})
      {:ok, %{"input" => "test", "result" => "hello"}}
  """
  def execute(lua_code, context \\ %{}, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    with :ok <- validate_program(lua_code),
         {:ok, lua_state} <- create_sandbox(),
         {:ok, lua_state} <- load_program(lua_state, lua_code),
         {:ok, lua_context, lua_state} <- elixir_to_lua(context, lua_state),
         {:ok, result, final_state} <- execute_with_timeout(lua_state, lua_context, opts) do
      case lua_to_elixir(result, final_state) do
        {:ok, elixir_result} -> {:ok, elixir_result}
        {:error, reason} -> {:error, "Failed to convert result: #{reason}"}
      end
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  @doc """
  Creates a new Luerl state with sandboxed environment and tool bindings.

  This sets up the Lua environment with:
  - Disabled dangerous functions (os, io, require, etc.)
  - Tool registry bindings
  - Safe standard library access (math, string, table)
  """
  def create_sandbox() do
    try do
      # Create a new Luerl state
      state = :luerl.init()

      # Remove dangerous functions
      state = remove_dangerous_functions(state)

      # Add tool bindings (will be implemented with ToolRegistry)
      state = add_tool_bindings(state)

      {:ok, state}
    rescue
      error -> {:error, "Failed to create sandbox: #{inspect(error)}"}
    end
  end

  @doc """
  Validates that a Lua program contains only allowed functions and constructs.

  ## Parameters
  - `lua_code`: String containing the Lua program to validate

  ## Returns
  - `:ok` if validation passes
  - `{:error, reason}` if validation fails
  """
  def validate_program(lua_code) do
    # Basic validation - check for required run function
    if String.contains?(lua_code, "function run(") do
      # Check for dangerous patterns - both direct and obfuscated
      check_dangerous_patterns(lua_code)
    else
      {:error, "Lua code must contain a 'run' function"}
    end
  end

  # Enhanced pattern checking for security bypass attempts
  defp check_dangerous_patterns(lua_code) do
    # Direct dangerous function calls
    direct_patterns = [
      ~r/\bos\./,
      ~r/\bio\./,
      ~r/\brequire\b/,
      ~r/\bload\b/,
      ~r/\bdofile\b/,
      ~r/\bloadfile\b/,
      ~r/\bgetfenv\b/,
      ~r/\bsetfenv\b/,
      ~r/\bdebug\./
    ]

    # Obfuscated access patterns
    obfuscated_patterns = [
      # _G table access patterns
      ~r/_G\s*\[\s*["']?os["']?\s*\]/,
      ~r/_G\s*\[\s*["']?io["']?\s*\]/,
      ~r/_G\s*\[\s*["']?require["']?\s*\]/,
      ~r/_G\s*\[\s*["']?debug["']?\s*\]/,
      ~r/_G\s*\[\s*["']?load["']?\s*\]/,
      ~r/_G\s*\[\s*["']?dofile["']?\s*\]/,
      ~r/_G\s*\[\s*["']?loadfile["']?\s*\]/,
      ~r/_G\s*\[\s*["']?getfenv["']?\s*\]/,
      ~r/_G\s*\[\s*["']?setfenv["']?\s*\]/,

      # Variable-based obfuscation (_G[variable])
      ~r/_G\s*\[\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\]/,

      # rawget access patterns
      ~r/rawget\s*\(\s*_G\s*,/,

      # String concatenation patterns for dangerous names
      ~r/["']o["']\s*\.\.\s*["']s["']/,  # "o" .. "s"
      ~r/["']i["']\s*\.\.\s*["']o["']/,  # "i" .. "o"
      ~r/["']req["']\s*\.\.\s*["']uire["']/,  # "req" .. "uire"
      ~r/["']deb["']\s*\.\.\s*["']ug["']/,   # "deb" .. "ug"

      # getmetatable on global table
      ~r/getmetatable\s*\(\s*_G\s*\)/,

      # Direct _G manipulation
      ~r/_G\s*\.\s*(os|io|require|debug|load|dofile|loadfile|getfenv|setfenv)/,

      # Package/module loading attempts
      ~r/package\s*\./,
      ~r/module\s*\(/
    ]

    all_patterns = direct_patterns ++ obfuscated_patterns

    dangerous_found = Enum.find(all_patterns, fn pattern ->
      Regex.match?(pattern, lua_code)
    end)

    case dangerous_found do
      nil -> :ok
      _pattern -> {:error, "Dangerous function call detected in Lua code"}
    end
  end

  @doc """
  Converts an Elixir map to a Lua table structure (arity 1 for backward compatibility).

  Note: This function creates its own Lua state and returns a table reference
  that is only valid within that specific state context. For most use cases,
  consider using the state-aware elixir_to_lua/2 function instead.
  """
  def elixir_to_lua(elixir_data) do
    case elixir_data do
      data when is_map(data) or is_list(data) ->
        with lua_code <- generate_lua_table_code(elixir_data),
             state <- :luerl.init(),
             {:ok, [table_ref], new_state} <- :luerl.do("return " <> lua_code, state) do
          # Store state with the table reference for later extraction
          {:ok, {table_ref, new_state}}
        else
          error -> {:error, "Failed to create Lua table: #{inspect(error)}"}
        end

      # For primitive values, return as-is
      primitive_value ->
        {:ok, primitive_value}
    end
  end

  @doc """
  Converts an Elixir map to a Lua table structure (arity 2 for state-aware conversion).
  """
  def elixir_to_lua(elixir_data, lua_state) do
    with lua_code <- generate_lua_table_code(elixir_data),
         {:ok, [table_ref], new_state} <- :luerl.do("return " <> lua_code, lua_state) do
      {:ok, table_ref, new_state}
    else
      error -> {:error, "Failed to create Lua table: #{inspect(error)}"}
    end
  end

  # Generate Lua table creation code from Elixir data
  defp generate_lua_table_code(map) when is_map(map) do
    elements = map
    |> Enum.map(fn {key, value} ->
      lua_key = format_lua_key(key)
      lua_value = format_lua_value(value)
      "#{lua_key} = #{lua_value}"
    end)
    |> Enum.join(", ")

    "{#{elements}}"
  end

  defp generate_lua_table_code(list) when is_list(list) do
    elements = list
    |> Enum.map(&format_lua_value/1)
    |> Enum.join(", ")

    "{#{elements}}"
  end

  defp generate_lua_table_code(value), do: format_lua_value(value)

  defp format_lua_key(atom) when is_atom(atom), do: "[\"#{to_string(atom)}\"]"
  defp format_lua_key(string) when is_binary(string) do
    # Check if the string is a valid Lua identifier
    if Regex.match?(~r/^[a-zA-Z_][a-zA-Z0-9_]*$/, string) do
      string
    else
      "[\"#{string}\"]"
    end
  end
  defp format_lua_key(value), do: "[#{format_lua_value(value)}]"

  defp format_lua_value(value) when is_binary(value), do: inspect(value)
  defp format_lua_value(value) when is_number(value), do: to_string(value)
  defp format_lua_value(true), do: "true"
  defp format_lua_value(false), do: "false"
  defp format_lua_value(nil), do: "nil"
  defp format_lua_value(value) when is_atom(value), do: inspect(to_string(value))
  defp format_lua_value(list) when is_list(list) do
    elements = Enum.map(list, &format_lua_value/1)
    "{" <> Enum.join(elements, ", ") <> "}"
  end
  defp format_lua_value(map) when is_map(map) do
    generate_lua_table_code(map)
  end
  defp format_lua_value(value), do: inspect(value)

  @doc """
  Converts a Lua table back to an Elixir map (arity 1 for backward compatibility).

  This function can handle:
  - Table references with their state: {table_ref, lua_state}
  - Standalone table references (will attempt to extract with a new state)
  - Primitive values (returned as-is)
  """
  def lua_to_elixir(lua_data) do
    case lua_data do
      {table_ref = {:tref, _}, lua_state} ->
        # Table reference with its state - use the provided state
        extract_table_contents(table_ref, lua_state)
      {:tref, _} = _table_ref ->
        # Standalone table reference - try with new state (may fail)
        {:error, "Cannot extract table without state"}
      _ ->
        # Primitive value - return as-is
        {:ok, lua_data}
    end
  end

  @doc """
  Converts a Lua table back to an Elixir map (arity 2 for state-aware conversion).
  """
  def lua_to_elixir(lua_data, lua_state) do
    case lua_data do
      {:tref, _} -> extract_table_contents(lua_data, lua_state)
      _ -> {:ok, lua_data}
    end
  end

  # Set the table reference as a global variable so we can introspect it
  defp set_temp_table(table_ref, lua_state) do
    try do
      case :luerl.call_function(["rawset"], [{:tref, 0}, "temp_table", table_ref], lua_state) do
        {:ok, _result, new_state} -> {:ok, new_state}
        error -> {:error, "Failed to set temp table: #{inspect(error)}"}
      end
    rescue
      error -> {:error, "Exception setting temp table: #{inspect(error)}"}
    end
  end

  # Extract table contents with circular reference detection
  defp extract_table_contents(table_ref, lua_state, visited \\ MapSet.new()) do
    # Check if we've already seen this table reference
    table_id = extract_table_id(table_ref)

    if MapSet.member?(visited, table_id) do
      # Circular reference detected - return a placeholder
      {:ok, %{"__circular_ref" => table_id}}
    else
      updated_visited = MapSet.put(visited, table_id)

      with {:ok, state} <- set_temp_table(table_ref, lua_state),
           {:ok, contents} <- extract_all_pairs(state, %{}, nil, updated_visited) do
        {:ok, contents}
      else
        error -> {:error, "Failed to extract table: #{inspect(error)}"}
      end
    end
  end

  # Extract a unique identifier from the table reference
  defp extract_table_id({:tref, id}), do: id

  # Extract all key-value pairs from the temp_table with circular reference detection
  defp extract_all_pairs(lua_state, acc_map, prev_key, visited) do
    next_code = case prev_key do
      nil -> "return next(temp_table)"
      key -> "return next(temp_table, #{format_lua_value(key)})"
    end

    case :luerl.do(next_code, lua_state) do
      {:ok, [nil], _state} ->
        # No more keys - convert to list if it's array-like
        convert_map_to_appropriate_type(acc_map)
      {:ok, [key, value], state} ->
        # Got a key-value pair, convert value if needed
        elixir_value = case value do
          {:tref, _} ->
            case extract_table_contents(value, state, visited) do
              {:ok, nested} -> nested
              _ -> value
            end
          _ -> value
        end
        new_map = Map.put(acc_map, key, elixir_value)
        extract_all_pairs(state, new_map, key, visited)
      {:ok, [], _state} ->
        # Empty table
        {:ok, %{}}
      error ->
        {:error, "Failed to get next pair: #{inspect(error)}"}
    end
  end

  # Convert map to list if it has consecutive integer keys starting from 1
  defp convert_map_to_appropriate_type(map) when map_size(map) == 0, do: {:ok, %{}}

  defp convert_map_to_appropriate_type(map) do
    keys = Map.keys(map)

    # Check if all keys are integers and consecutive starting from 1
    integer_keys = keys
    |> Enum.filter(&is_integer/1)
    |> Enum.sort()

    expected_keys = if length(integer_keys) > 0 do
      1..length(integer_keys) |> Enum.to_list()
    else
      []
    end

    if integer_keys == expected_keys and length(integer_keys) == map_size(map) do
      # Convert to list
      list = integer_keys
      |> Enum.map(fn key -> Map.get(map, key) end)
      {:ok, list}
    else
      # Keep as map, but convert integer keys to strings for consistency
      string_map = map
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        Map.put(acc, to_string(key), value)
      end)
      {:ok, string_map}
    end
  end

  # Private helper functions

  defp load_program(lua_state, lua_code) do
    try do
      case :luerl.do(lua_code, lua_state) do
        {:ok, _result, updated_state} -> {:ok, updated_state}
        {:error, reason} -> {:error, "Failed to load Lua program: #{inspect(reason)}"}
        error -> {:error, "Failed to load Lua program: #{inspect(error)}"}
      end
    rescue
      error -> {:error, "Failed to load Lua program: #{inspect(error)}"}
    end
  end

  defp execute_with_timeout(lua_state, lua_context, opts) do
    timeout = Keyword.get(opts, :timeout)
    memory_limit = Keyword.get(opts, :memory_limit)

    task = Task.async(fn ->
      try do
        # Check memory before execution
        if memory_limit do
          case check_memory_usage(memory_limit) do
            :ok -> :ok
            {:error, reason} -> throw({:memory_error, reason})
          end
        end

        # Call the run function with the context
        result = :luerl.call_function(["run"], [lua_context], lua_state)

        # Check memory after execution
        if memory_limit do
          case check_memory_usage(memory_limit) do
            :ok -> :ok
            {:error, reason} -> throw({:memory_error, reason})
          end
        end

        case result do
          {:ok, [result], final_state} -> {:ok, result, final_state}
          {:error, reason} -> {:error, "Lua execution failed: #{inspect(reason)}"}
          error -> {:error, "Lua execution failed: #{inspect(error)}"}
        end
      rescue
        error -> {:error, "Lua execution failed: #{inspect(error)}"}
      catch
        {:memory_error, reason} -> {:error, reason}
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, result, final_state}} -> {:ok, result, final_state}
      {:ok, {:error, reason}} -> {:error, reason}
      nil -> {:error, "Execution timeout"}
      _other -> {:error, "Unexpected execution result"}
    end
  end

  # Check current memory usage against limit
  defp check_memory_usage(memory_limit) do
    case Process.info(self(), :memory) do
      {_, memory_bytes} when memory_bytes > memory_limit ->
        {:error, "Memory limit exceeded: #{memory_bytes} bytes > #{memory_limit} bytes"}
      {_, _} ->
        :ok
      nil ->
        {:error, "Could not check memory usage"}
    end
  end

  defp remove_dangerous_functions(state) do
    # Remove dangerous global functions
    dangerous_globals = ["os", "io", "require", "load", "dofile", "loadfile", "getfenv", "setfenv", "debug"]

    Enum.reduce(dangerous_globals, state, fn global, acc_state ->
      case :luerl.do("#{global} = nil", acc_state) do
        {:ok, _result, updated_state} -> updated_state
        _error -> acc_state  # If setting fails, continue with the current state
      end
    end)
  end

  defp add_tool_bindings(state) do
    # Define Elixir functions that will be called from Lua
    http_get_func = fn
      [url], lua_state when is_binary(url) ->
        result = NetsukeAgents.ToolRouter.http_get(url)
        {[result], lua_state}
      [_], lua_state ->
        {["Invalid URL parameter"], lua_state}
      [], lua_state ->
        {["URL parameter required"], lua_state}
    end

    http_post_func = fn
      [url, options], lua_state when is_binary(url) ->
        try do
          # Convert Lua table to Elixir map
          elixir_options = case options do
            {:tref, _} ->
              case lua_to_elixir(options, lua_state) do
                {:ok, converted} -> converted
                {:error, _} -> %{}
              end
            _ ->
              %{}
          end

          result = NetsukeAgents.ToolRouter.http_post(url, elixir_options)
          {[result], lua_state}
        rescue
          error ->
            error_msg = "HTTP POST error: #{inspect(error)}"
            {[error_msg], lua_state}
        end
      [url], lua_state when is_binary(url) ->
        result = NetsukeAgents.ToolRouter.http_post(url, %{})
        {[result], lua_state}
      [_], lua_state ->
        {["Invalid parameters"], lua_state}
      [], lua_state ->
        {["URL parameter required"], lua_state}
    end

    json_decode_func = fn
      [json_string], lua_state when is_binary(json_string) ->
        result = NetsukeAgents.ToolRouter.json_decode(json_string)
        # Convert the result to Lua table using Luerl's encode function
        case result do
          data when is_map(data) ->
            # Use Luerl's encode to properly convert the map to a Lua table
            {encoded_data, new_state} = :luerl.encode(data, lua_state)
            {[encoded_data], new_state}
          _ ->
            {[result], lua_state}
        end
      [_], lua_state ->
        {["Invalid JSON parameter"], lua_state}
      [], lua_state ->
        {["JSON string parameter required"], lua_state}
    end

    json_encode_func = fn
      [data], lua_state ->
        try do
          # Handle different types of Lua data
          elixir_data = case data do
            {:tref, _} ->
              # It's a table reference, use our existing conversion
              case lua_to_elixir(data, lua_state) do
                {:ok, converted} -> converted
                {:error, _} -> data
              end
            _ ->
              # It's a primitive value or already converted
              data
          end

          result = NetsukeAgents.ToolRouter.json_encode(elixir_data)
          {[result], lua_state}
        rescue
          error ->
            error_msg = "JSON encode error: #{inspect(error)}"
            {[error_msg], lua_state}
        end
      [], lua_state ->
        {["Data parameter required"], lua_state}
    end

    try do
      # First, create empty tables
      case :luerl.do("http = {}; json = {}", state) do
        {:ok, _, state1} ->
          # Encode the functions properly for Luerl
          {encoded_http_get_func, state2} = :luerl.encode(http_get_func, state1)
          {encoded_http_post_func, state3} = :luerl.encode(http_post_func, state2)
          {encoded_json_decode_func, state4} = :luerl.encode(json_decode_func, state3)
          {encoded_json_encode_func, state5} = :luerl.encode(json_encode_func, state4)

          # Now set the actual functions using the correct Luerl API
          with {:ok, state6} <- :luerl.set_table_keys(["http", "get"], encoded_http_get_func, state5),
               {:ok, state7} <- :luerl.set_table_keys(["http", "post"], encoded_http_post_func, state6),
               {:ok, state8} <- :luerl.set_table_keys(["json", "decode"], encoded_json_decode_func, state7),
               {:ok, final_state} <- :luerl.set_table_keys(["json", "encode"], encoded_json_encode_func, state8) do
            final_state
          else
            {:error, _} -> state5
          end
        {:error, _} -> state
      end

    rescue
      _error ->
        # Fallback: create empty tables with error messages
        lua_setup = """
        http = {
          get = function(url)
            error("http.get is not yet implemented")
          end,
          post = function(url, options)
            error("http.post is not yet implemented")
          end
        }

        json = {
          decode = function(json_string)
            error("json.decode is not yet implemented")
          end,
          encode = function(data)
            error("json.encode is not yet implemented")
          end
        }
        """

        case :luerl.do(lua_setup, state) do
          {:ok, _, new_state} -> new_state
          _ -> state
        end
    end
  end
end
