defmodule Apero.MixProject do
  use Mix.Project

  def project do
    [
      app: :apero,
      version: "3.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Apero",
      description:
        "Pure utility library for Elixir — file operations, cryptography, Docker, package managers, env/config, retry, cache, and OS/Proc introspection. Uses System.cmd for shell operations (no Arrea dependency).",
      source_url: "https://github.com/Lorenzo-SF/apero",
      homepage_url: "https://github.com/Lorenzo-SF/apero",
      package: [
        name: :apero,
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/Lorenzo-SF/apero"},
        maintainers: ["Lorenzo Sánchez"]
      ],
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer_config(),
      test_coverage: [tool: ExCoveralls, threshold: 80]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {Apero.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :file_system, :public_key]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, ">= 1.0.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"},
      {:file_system, "~> 1.0"},
      {:yaml_elixir, "~> 2.9", optional: true},
      {:toml, "~> 0.7", optional: true}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "docs/README.es.md", "LICENSE.md"],
      groups_for_modules: [
        Core: [
          Apero,
          Apero.Application,
          Apero.Cache,
          Apero.Cache.Adapter,
          Apero.Cache.Ets,
          Apero.Cache.Supervisor
        ],
        "File & Path": [
          Apero.File,
          Apero.File.IO,
          Apero.File.Path,
          Apero.File.Tree,
          Apero.File.Watcher
        ],
        Security: [
          Apero.Crypto,
          Apero.Crypto.Hash,
          Apero.Crypto.Cipher,
          Apero.Crypto.Key,
          Apero.Crypto.Random
        ],
        Environment: [Apero.Env, Apero.Conf],
        System: [Apero.OS, Apero.Proc],
        "Retry & Cache": [Apero.Retry, Apero.Cache]
      ],
      source_url: "https://github.com/Lorenzo-SF/apero",
      homepage_url: "https://github.com/Lorenzo-SF/apero",
      source_ref: "3.0.0"
    ]
  end

  defp dialyzer_config do
    [
      plt_file: {:no_warn, "priv/plts/apero"},
      plt_core_path: "priv/plts/core",
      plt_add_apps: [:mix],
      flags: [:error_handling, :no_opaque, :no_underspecs],
      ignore_warnings: ".dialyzer-ignore-warnings"
    ]
  end

  defp aliases do
    [
      qa: [
        "format",
        "compile",
        "dialyzer",
        "test --cover"
      ]
    ]
  end
end
