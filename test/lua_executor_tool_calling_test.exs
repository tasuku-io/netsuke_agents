defmodule NetsukeAgents.LuaExecutorToolCallingTest do
  use ExUnit.Case, async: true
  alias NetsukeAgents.LuaExecutor

  describe "dynamic tool calling" do
    test "calls http.get from Lua code" do
      lua_code = """
      function run(context)
        local response = http.get("https://jsonplaceholder.typicode.com/posts/1")
        context["response"] = response
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["response"])
      assert String.contains?(result["response"], "userId")
    end

    test "calls json.decode from Lua code" do
      lua_code = """
      function run(context)
        local json_string = '{"name": "test", "value": 42}'
        local decoded = json.decode(json_string)
        context["decoded"] = decoded
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_map(result["decoded"])
      assert result["decoded"]["name"] == "test"
      assert result["decoded"]["value"] == 42
    end

    test "combines http.get and json.decode" do
      lua_code = """
      function run(context)
        local response = http.get("https://jsonplaceholder.typicode.com/posts/1")
        local data = json.decode(response)
        context["title"] = data["title"]
        context["userId"] = data["userId"]
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["title"])
      assert is_number(result["userId"])
    end

    test "real-world scenario: PokeAPI call like the example script" do
      # This mimics what an AI agent might generate for the PokeAPI request
      lua_code = """
      function run(context)
        local response = http.get("https://pokeapi.co/api/v2/pokemon/bulbasaur/")

        local pokemon_data = json.decode(response)

        context["pokemon_id"] = pokemon_data["id"]
        context["pokemon_name"] = pokemon_data["name"]
        context["pokemon_height"] = pokemon_data["height"]
        context["pokemon_weight"] = pokemon_data["weight"]

        context["raw_response"] = response

        return context
      end
      """

      context = %{
        "request_url" => "https://pokeapi.co/api/v2/pokemon/bulbasaur/",
        "target_field" => "id"
      }

      assert {:ok, result} = LuaExecutor.execute(lua_code, context)

      # Verify we got the expected results
      assert result["pokemon_id"] == 1  # Bulbasaur's ID is 1
      assert result["pokemon_name"] == "bulbasaur"
      assert is_number(result["pokemon_height"])
      assert is_number(result["pokemon_weight"])
      assert is_binary(result["raw_response"])

      # Verify original context is preserved
      assert result["request_url"] == "https://pokeapi.co/api/v2/pokemon/bulbasaur/"
      assert result["target_field"] == "id"

      # Verify the raw response contains JSON
      assert String.contains?(result["raw_response"], "bulbasaur")
      assert String.contains?(result["raw_response"], "\"id\"")
    end

    test "handles unknown tool calls gracefully" do
      lua_code = """
      function run(context)
        local result = unknown_tool.call("test")
        context["result"] = result
        return context
      end
      """

      # Should either fail gracefully or return an error
      result = LuaExecutor.execute(lua_code, %{})
      case result do
        {:ok, _} -> :ok  # If it somehow succeeds
        {:error, reason} ->
          assert is_binary(reason)
          assert String.contains?(reason, "unknown") or String.contains?(reason, "function")
      end
    end

    test "handles tool call errors gracefully" do
      lua_code = """
      function run(context)
        local response = http.get("invalid-url")
        context["response"] = response
        return context
      end
      """

      result = LuaExecutor.execute(lua_code, %{})
      case result do
        {:ok, ctx} ->
          # Tool should return error message as string
          assert is_binary(ctx["response"])
        {:error, _} ->
          # Or execution fails entirely
          assert true
      end
    end
  end
end
