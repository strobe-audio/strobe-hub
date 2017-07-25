defmodule Otis.Library.UPNP.Mixfile do
  use Mix.Project

  def project do
    [app: :otis_library_upnp,
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

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Otis.Library.UPNP.Application, []}]
  end

  defp deps do
    [ {:nerves_ssdp_client, "~> 0.1.3"},
      {:sweet_xml, "~> 0.6.5"},
      {:httpoison, "~> 0.11.1"},
      {:erlsom, github: "willemdj/erlsom"},
      {:xml_builder, "~> 0.0.9"},
      {:otis_library, in_umbrella: true},
      {:httparrot, "~> 1.0.0", only: :test},
      {:gen_stage, "~> 0.12"},
      {:poison, "~> 1.0"},
    ]
  end
end
