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
    [ mod: {Peel, []},
      applications: [
        :logger,
        :ecto,
        :erlsom,
        :floki,
        :gen_stage,
        :httpoison,
        :otis_library,
        :poison,
        :sqlite_ecto,
        :uuid,
        :work_queue,
        :plug_webdav,
        :strobe_events,
      ],
      included_applications: [
      ],
    ]
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
    [ {:ecto, "~> 1.0"},
      {:erlsom, github: "willemdj/erlsom"},
      {:floki, "~> 0.11.0"},
      {:flow, "~> 0.11"},
      {:gen_stage, "~> 0.12"},
      {:httpoison, "~> 0.11.1"},
      {:otis_library, in_umbrella: true},
      {:poison, "~> 1.0"},
      {:sqlite_ecto, github: "magnetised/sqlite_ecto"},
      {:uuid, "~> 1.1"},
      {:work_queue, github: "magnetised/work_queue"},
      {:plug, "~> 1.3.0"},
      {:plug_webdav, in_umbrella: true},
      {:strobe_events, in_umbrella: true},
    ]
  end
end
