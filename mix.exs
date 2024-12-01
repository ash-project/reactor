defmodule Reactor.MixProject do
  use Mix.Project

  @version "0.10.2"
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
      dialyzer: [plt_add_apps: [:mix]],
      docs: [
        main: "readme",
        logo: "logos/reactor-logo-light-small.png",
        extras: extra_documentation(),
        groups_for_extras: extra_documentation_groups(),
        before_closing_head_tag: fn type ->
          if type == :html do
            """
            <script>
              if (location.hostname === "hexdocs.pm") {
                var script = document.createElement("script");
                script.src = "https://plausible.io/js/script.js";
                script.setAttribute("defer", "defer")
                script.setAttribute("data-domain", "ashhexdocs")
                document.head.appendChild(script);
              }
            </script>
            """
          end
        end,
        groups_for_modules: [
          Dsl: ~r/^Reactor\.Dsl.*/,
          Steps: ~r/^Reactor\.Step.*/,
          Middleware: ~r/^Reactor\.Middleware.*/,
          Errors: ~r/^Reactor\.Error.*/,
          Builder: ~r/^Reactor\.Builder.*/,
          Internals: ~r/^Reactor\..*/
        ],
        extra_section: "GUIDES",
        formatters: ["html"],
        filter_modules: ~r/^Elixir.Reactor/,
        source_url_pattern: "https://github.com/ash-project/reactor/blob/main/%{path}/#L%{line}",
        spark: [
          extensions: [
            %{
              module: Reactor.Dsl,
              name: "Reactor.Dsl",
              target: "Reactor",
              type: "Reactor"
            }
          ]
        ]
      ]
    ]
  end

  defp package do
    [
      name: :reactor,
      files: ~w[lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/reactor"
      },
      maintainers: [
        "James Harton <james@harton.nz>",
        "Zach Daniel <zach@zachdaniel.dev>"
      ],
      source_url: "https://github.com/ash-project/reactor"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Reactor.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:spark, "~> 2.0"},
      {:splode, "~> 0.2"},
      {:libgraph, "~> 0.16"},
      {:igniter, "~> 0.2"},
      {:iterex, "~> 0.1"},
      {:telemetry, "~> 1.2"},

      # Dev/Test dependencies
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.18", only: [:dev, :test], runtime: false},
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16.0", only: [:dev, :test]},
      {:git_ops, "~> 2.6.0", only: [:dev, :test]},
      {:mimic, "~> 1.7", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(env) when env in ~w[dev test]a do
    elixirc_paths(:prod) ++ ["test/support"]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.cheat_sheets_in_search",
        "spark.replace_doc_links"
      ],
      "spark.formatter": "spark.formatter --extensions Reactor.Dsl",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions Reactor.Dsl",
      "spark.cheat_sheets_in_search": "spark.cheat_sheets_in_search --extensions Reactor.Dsl"
    ]
  end

  defp extra_documentation do
    ["README.md"]
    |> Enum.concat(Path.wildcard("documentation/**/*.{md,livemd,cheatmd}"))
    |> Enum.map(fn
      "README.md" ->
        {:"README.md", title: "Read Me", ash_hq?: false}

      "documentation/tutorials/" <> _ = path ->
        {String.to_atom(path), []}

      "documentation/topics/" <> _ = path ->
        {String.to_atom(path), []}

      "documentation/dsls/" <> _ = path ->
        {String.to_atom(path), []}
    end)
  end

  defp extra_documentation_groups do
    [
      Tutorials: ~r'documentation/tutorials',
      DSLs: ~r'documentation/dsls'
    ]
  end
end
