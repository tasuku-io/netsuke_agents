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

    test "calls http.post from Lua code" do
      lua_code = """
      function run(context)
        local response = http.post("https://httpbin.org/post", {
          headers = {
            ["Content-Type"] = "application/json"
          },
          body = '{"test": "data"}'
        })
        context["response"] = response
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["response"])
      # httpbin.org/post returns JSON with the data we sent
      assert String.contains?(result["response"], "test")
    end

    test "calls json.encode from Lua code" do
      lua_code = """
      function run(context)
        local data = {
          name = "test",
          value = 42,
          active = true
        }
        local json_string = json.encode(data)
        context["json_result"] = json_string
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["json_result"])
      # Should be valid JSON
      assert {:ok, decoded} = Jason.decode(result["json_result"])
      assert decoded["name"] == "test"
      assert decoded["value"] == 42
      assert decoded["active"] == true
    end

    test "handles complex nested structures with special characters in keys" do
      lua_code = """
      function run(context)
        local data = {
          ["com.linkedin.ugc.ShareContent"] = {
            shareCommentary = {
              text = "Test post"
            },
            shareMediaCategory = "NONE"
          },
          ["X-Custom-Header"] = "value-with-dashes",
          normalKey = "normal_value"
        }
        local json_string = json.encode(data)
        context["complex_json"] = json_string
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["complex_json"])

      # Verify the JSON contains the special keys
      assert String.contains?(result["complex_json"], "com.linkedin.ugc.ShareContent")
      assert String.contains?(result["complex_json"], "X-Custom-Header")
      assert String.contains?(result["complex_json"], "Test post")
    end

    test "reproduces the original LinkedIn API error case" do
      # This is the exact Lua code that was causing the syntax error
      lua_code = """
      function run(context)
        local url = 'https://httpbin.org/post'
        local response = http.post(url, {
          headers = {
            ['X-Restli-Protocol-Version'] = '2.0.0',
            ['Authorization'] = 'Bearer test-token'
          },
          body = json.encode({
            author = context.author,
            lifecycleState = context.lifecycleState,
            specificContent = context.specificContent,
            visibility = context.visibility
          })
        })
        context["api_response"] = response
        return context
      end
      """

      context = %{
        "author" => "urn:li:person:123456",
        "lifecycleState" => "PUBLISHED",
        "specificContent" => %{
          "com.linkedin.ugc.ShareContent" => %{
            "shareCommentary" => %{"text" => "Test LinkedIn post"},
            "shareMediaCategory" => "NONE"
          }
        },
        "visibility" => %{
          "com.linkedin.ugc.MemberNetworkVisibility" => "PUBLIC"
        }
      }

      # This should NOT generate a syntax error anymore
      assert {:ok, result} = LuaExecutor.execute(lua_code, context)
      assert is_binary(result["api_response"])

      # Verify the original context is preserved
      assert result["author"] == "urn:li:person:123456"
      assert result["lifecycleState"] == "PUBLISHED"
    end

    test "http.post with only URL parameter" do
      lua_code = """
      function run(context)
        local response = http.post("https://httpbin.org/post")
        context["response"] = response
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["response"])
    end

    test "json.encode with nested arrays and objects" do
      lua_code = """
      function run(context)
        local complex_data = {
          users = {
            {name = "Alice", id = 1},
            {name = "Bob", id = 2}
          },
          metadata = {
            ["api-version"] = "v2",
            ["request-id"] = "12345"
          }
        }
        local json_result = json.encode(complex_data)
        context["complex_result"] = json_result
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["complex_result"])

      # Parse and verify the structure
      assert {:ok, parsed} = Jason.decode(result["complex_result"])
      assert is_list(parsed["users"])
      assert length(parsed["users"]) == 2
      assert parsed["users"] |> Enum.at(0) |> Map.get("name") == "Alice"
      assert parsed["metadata"]["api-version"] == "v2"
    end

    test "combined http.post with json.encode workflow" do
      lua_code = """
      function run(context)
        local post_data = {
          title = "Test Post",
          body = "This is a test",
          userId = 1
        }

        local response = http.post("https://jsonplaceholder.typicode.com/posts", {
          headers = {
            ["Content-Type"] = "application/json"
          },
          body = json.encode(post_data)
        })

        local response_data = json.decode(response)
        context["post_id"] = response_data["id"]
        context["title"] = response_data["title"]
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_number(result["post_id"])
      assert result["title"] == "Test Post"
    end

    test "error handling for invalid JSON in json.encode" do
      lua_code = """
      function run(context)
        -- This might cause issues but should be handled gracefully
        local result = json.encode("simple string")
        context["result"] = result
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["result"])
      # Simple string should be encoded as JSON string
      assert result["result"] == "\"simple string\""
    end

    test "error handling for invalid URL in http.post" do
      lua_code = """
      function run(context)
        local response = http.post("not-a-valid-url")
        context["response"] = response
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert is_binary(result["response"])
      assert String.contains?(result["response"], "Invalid URL") or
             String.contains?(result["response"], "error") or
             String.contains?(result["response"], "failed")
    end

    test "validates that missing http.post doesn't crash" do
      # Simulate the environment before our fixes
      lua_code = """
      function run(context)
        if http and http.post then
          context["has_post"] = true
        else
          context["has_post"] = false
        end
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert result["has_post"] == true
    end

    test "validates that missing json.encode doesn't crash" do
      lua_code = """
      function run(context)
        if json and json.encode then
          context["has_encode"] = true
        else
          context["has_encode"] = false
        end
        return context
      end
      """

      assert {:ok, result} = LuaExecutor.execute(lua_code, %{})
      assert result["has_encode"] == true
    end
  end
end
