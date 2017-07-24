defmodule HLS.Mixfile do
  use Mix.Project

  def project do
    [app: :otis_library_bbc,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     consolidate_protocols: Mix.env != :test,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison, :gen_stage, :gproc], mod: {BBC, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:httpoison, "~> 0.11.1"},
      {:gen_stage, "~> 0.12"},
      {:gproc, "~> 0.5.0"},
      {:poison, "~> 1.5.0"},
      {:otis_library, in_umbrella: true},
    ]
  end
end
