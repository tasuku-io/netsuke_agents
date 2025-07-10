defmodule NetsukeAgents.ToolRouter do
  @moduledoc """
  Handles dynamic tool calls from Lua code execution.

  This module provides a safe interface for Lua code to interact with external
  systems like HTTP APIs and JSON processing while maintaining security boundaries.
  """

  require Logger

  @doc """
  Makes an HTTP GET request to the specified URL.

  ## Parameters
  - `url`: String URL to request

  ## Returns
  - Binary response body on success
  - Error message string on failure
  """
  def http_get(url) when is_binary(url) do
    Logger.info("ToolRouter.http_get called with URL: #{url}")

    case validate_url(url) do
      :ok ->
        case Finch.build(:get, url) |> Finch.request(NetsukeAgents.Finch) do
          {:ok, %Finch.Response{status: 200, body: body}} ->
            body
          {:ok, %Finch.Response{status: status}} ->
            "HTTP Error: #{status}"
          {:error, reason} ->
            "Request failed: #{inspect(reason)}"
        end
      {:error, reason} ->
        "Invalid URL: #{reason}"
    end
  end

  def http_get(_), do: "Invalid URL parameter"

  @doc """
  Decodes a JSON string into Lua-compatible data.

  ## Parameters
  - `json_string`: String containing valid JSON

  ## Returns
  - Decoded data structure on success
  - Error message string on failure
  """
  def json_decode(json_string) when is_binary(json_string) do
    Logger.info("ToolRouter.json_decode called")

    case Jason.decode(json_string) do
      {:ok, data} ->
        # Return a simplified map with only simple values that Lua can handle
        simplify_data(data)
      {:error, reason} -> "JSON decode error: #{inspect(reason)}"
    end
  end

  # Private helper functions

  defp simplify_data(data) when is_map(data) do
    data
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case simplify_value(v) do
        nil -> acc  # Skip complex values that can't be simplified
        simple_v -> Map.put(acc, k, simple_v)
      end
    end)
  end

  defp simplify_data(data) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {v, i}, acc ->
      case simplify_value(v) do
        nil -> acc
        simple_v -> Map.put(acc, to_string(i + 1), simple_v)  # Lua arrays start at 1
      end
    end)
  end

  defp simplify_data(data), do: data

  defp simplify_value(v) when is_binary(v) or is_number(v) or is_boolean(v), do: v
  defp simplify_value(nil), do: nil
  defp simplify_value(v) when is_map(v) do
    # Only keep simple nested values for essential fields
    essential_fields = ["id", "name", "height", "weight", "base_experience", "url"]
    case Map.take(v, essential_fields) do
      empty when map_size(empty) == 0 -> nil
      simple -> simplify_data(simple)
    end
  end
  defp simplify_value(v) when is_list(v) do
    case length(v) do
      len when len > 5 -> nil  # Skip long arrays to avoid complexity
      _ -> simplify_data(v)
    end
  end
  defp simplify_value(_), do: nil  # Skip other complex types

  defp validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        if allowed_host?(host) do
          :ok
        else
          {:error, "Host not allowed: #{host}"}
        end
      _ ->
        {:error, "Invalid URL format"}
    end
  end

  defp allowed_host?(host) do # TODO: Set this up at agent or user level
    # For now, allow common testing APIs
    # In production, you'd want a more restrictive allowlist
    allowed_hosts = [
      "jsonplaceholder.typicode.com",
      "httpbin.org",
      "api.github.com",
      "pokeapi.co"
    ]

    host in allowed_hosts or String.ends_with?(host, ".local")
  end
end
