defmodule Intellispark.MixProject do
  use Mix.Project

  def project do
    [
      app: :intellispark,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {Intellispark.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix core
      {:phoenix, "~> 1.8.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Ash core + data layer
      {:ash, "~> 3.24"},
      {:ash_postgres, "~> 2.9"},
      {:ash_phoenix, "~> 2.3"},

      # Ash extensions wired up in Phase 0; some start being used in later phases
      {:ash_authentication, "~> 4.13"},
      {:ash_authentication_phoenix, "~> 2.16"},
      {:bcrypt_elixir, "~> 3.1"},
      {:picosat_elixir, "~> 0.2"},
      {:ash_oban, "~> 0.8"},
      {:ash_paper_trail, "~> 0.5"},
      {:ash_archival, "~> 2.0"},
      {:ash_state_machine, "~> 0.2"},
      {:ash_admin, "~> 1.1"},

      # Supporting libraries
      {:oban, "~> 2.21"},
      {:oban_web, "~> 2.12"},
      {:swoosh, "~> 1.25"},
      {:req, "~> 0.5"},
      {:finch, "~> 0.21"},
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.3"},
      {:hammer, "~> 7.3"},

      # Observability (wired up in Phase 17; installed now so nothing is missing later)
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_phoenix, "~> 2.0"},

      # Dev / test tooling
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:stream_data, "~> 1.1"},
      {:mox, "~> 1.2", only: :test},
      {:sourceror, "~> 1.7", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build"],
      "ash.setup": ["ash.codegen --dev", "ash.migrate", "run priv/repo/seeds.exs"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind intellispark", "esbuild intellispark"],
      "assets.deploy": [
        "tailwind intellispark --minify",
        "esbuild intellispark --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
