defmodule Elvis.Mixfile do
  use Mix.Project

  def project do
    [app: :elvis,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env()),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env() == :prod,
     start_permanent: Mix.env() == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {Elvis, []},
     applications: [
       :logger,
       :logger_papertrail_backend,
       :phoenix,
       :phoenix_html,
       :cowboy,
       :otis,
       # fix missing apps from other dependencies
       :socket,
       :pipe,
       :peel,
       :otis_library_bbc,
       :otis_library_upnp,
       :otis_library_airplay,
     ]]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:phoenix, "~> 1.1.4"},
     {:phoenix_html, "~> 2.1"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:cowboy, "~> 1.1"},
     {:otis, in_umbrella: true},
     {:peel, in_umbrella: true},
     {:otis_library_bbc, in_umbrella: true},
     {:otis_library_upnp, in_umbrella: true},
     {:otis_library_airplay, in_umbrella: true},
     {:distillery, "~> 1.0"},
     {:logger_papertrail_backend, "~> 0.1.0"},
   ]
  end
end
