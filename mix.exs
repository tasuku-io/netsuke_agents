defmodule NetsukeAgents.MixProject do
  use Mix.Project

  def project do
    [
      app: :netsuke_agents,
      version: "0.0.1-alpha.6",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/tasuku-io/netsuke_agents"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :observer, :wx, :runtime_tools],
      mod: {NetsukeAgents.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.0"},
      {:instructor, "~> 0.1.0"},
      {:luerl, ">= 1.4.0"},
      {:finch, "~> 0.20.0"},

      # Dev/test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
    ]
  end

  defp description do
    "A flexible Elixir library for building, validating, and managing AI agents with structured memory and schema validation."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/tasuku-io/netsuke_agents",
        "Docs" => "https://hexdocs.pm/netsuke_agents"
      },
      maintainers: ["Luis Guzman"],
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "NetsukeAgents",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
