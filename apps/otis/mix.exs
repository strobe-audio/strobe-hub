defmodule Otis.Mixfile do
  use Mix.Project

  def project do
    [app: :otis,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:porcelain, :logger, :dnssd, :monotonic],
     mod: {Otis, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [ {:porcelain, "~> 2.0"},
      {:dnssd, github: "benoitc/dnssd_erlang"},
      {:poolboy, github: "devinus/poolboy"},
      {:monotonic, github: "magnetised/monotonic.ex"},
    ]
  end
end
