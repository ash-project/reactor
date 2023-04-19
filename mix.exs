defmodule Reactor.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "An asynchronous, graph-based execution engine"

  def project do
    [
      app: :reactor,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      source_url: "https://github.com/ash-project/reactor",
      homepage_url: "https://github.com/ash-project/reactor",
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  defp package do
    [
      name: :reactor,
      files: ~w[lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/reactor"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dev/Test dependencies
      {:ex_doc, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12.0", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.4.4", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:prod) ++ ["test/support"]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict"
    ]
  end
end
