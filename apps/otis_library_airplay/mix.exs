defmodule Otis.Library.Airplay.Mixfile do
  use Mix.Project

  def project do
    [app: :otis_library_airplay,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env != :test,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Otis.Library.Airplay.Application, []}]
  end

  defp deps do
    [{:otis_library, in_umbrella: true},
     {:gen_stage, "~> 0.12"},
     {:external_process, in_umbrella: true},
     {:poison, "~> 1.5.0"},
    ]
  end
end
