defmodule Peel.Mixfile do
  use Mix.Project

  def project do
    [
      app: :peel,
      version: "0.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Peel.Cli],
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [mod: {Peel, []}, extra_applications: [:logger], included_applications: []]
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
    [
      {:ecto, "~> 2.2"},
      {:erlsom, github: "willemdj/erlsom"},
      {:floki, "~> 0.11.0"},
      {:flow, "~> 1.0"},
      {:finch, "~> 0.10"},
      {:otis_library, in_umbrella: true},
      {:poison, "~> 3.0"},
      {:sqlite_ecto2, "~> 2.4"},
      {:uuid, "~> 1.1"},
      {:work_queue, github: "magnetised/work_queue"},
      {:plug, "~> 1.3"},
      {:plug_webdav, in_umbrella: true},
      {:strobe_events, in_umbrella: true}
    ]
  end
end
