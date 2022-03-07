defmodule Otis.Mixfile do
  use Mix.Project

  def project do
    [
      app: :otis,
      version: "0.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Otis, []},
      env: env(),
      start_phases: [
        run_migrations: []
      ]
    ]
  end

  def env do
    [receiver_logger: [addr: {224, 0, 0, 224}, port: 9999]]
  end

  defp deps do
    [
      {:poolboy, "~> 1.4"},
      {:monotonic, github: "strobe-audio/monotonic", branch: "remove-erlang-application"},
      {:erlsom, github: "willemdj/erlsom"},
      {:uuid, "~> 1.1"},
      {:sqlite_ecto2, "~> 2.4"},
      {:ecto, "~> 2.2"},
      # {:ranch, "~> 1.3.2", [optional: false, hex: :ranch, manager: :rebar]},
      {:ranch, "~> 1.8"},
      {:otis_library, in_umbrella: true},
      {:poison, "~> 3.0"},
      {:external_process, in_umbrella: true},
      {:strobe_events, in_umbrella: true},
      {:nerves_ssdp_server, "~> 0.2.1"},
      {:mdns, "~> 1.0.9"}
    ]
  end
end
