defmodule Aurora.Ctx.MixProject do
  use Mix.Project

  @source_url "https://github.com/wadvanced/aurora_ctx"
  @version "0.1.7"

  def project do
    [
      app: :aurora_ctx,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      aliases: aliases(),

      # Hex
      description: "A macro set for exposing schema access functions in context modules",
      package: [
        maintainers: ["Federico Alcántara"],
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib),
        exclude_patterns: ["lib/aurora/ctx/repo.ex", ~r"/-local-.*"]
      ],

      # Docs
      name: "Aurora.Ctx",
      docs: &docs/0
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
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},

      ## Dev dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:doctor, "~> 0.22", only: :dev, runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      consistency: [
        "format",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "doctor"
      ],
      test: [
        "ctx.test.setup",
        "test"
      ]
    ]
  end

  defp docs do
    [
      main: "overview",
      logo: "./guides/images/aurora_ctx-icon.png",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: [
        Aurora.Ctx.Repo,
        ~r/-local-.*/
      ],
      extras: [
        "guides/overview.md",
        "guides/functions.md",
        "guides/examples.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.?/
      ],
      groups_for_modules: [
        Core: [
          Aurora.Ctx
        ],
        Helpers: [
          Aurora.Ctx.QueryBuilder
        ]
      ]
    ]
  end
end
