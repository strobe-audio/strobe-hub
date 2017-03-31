defmodule Peel.Mixfile do
  use Mix.Project

  def project do
    [app: :peel,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     consolidate_protocols: Mix.env != :test,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     escript: [main_module: Peel.Cli],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :sqlite_ecto, :ecto, :work_queue, :otis_library, :uuid, :httpoison, :floki, :poison],
     mod: {Peel, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:uuid, "~> 1.1"},
      {:sqlite_ecto, github: "magnetised/sqlite_ecto"},
      {:ecto, "~> 1.0"},
      {:work_queue, github: "magnetised/work_queue"},
      {:otis_library, in_umbrella: true},
      {:httpoison, "~> 0.11.1"},
      {:floki, "~> 0.11.0"},
      {:poison, "~> 1.0"},
      {:otis, in_umbrella: true, only: :test},
    ]
  end
end
