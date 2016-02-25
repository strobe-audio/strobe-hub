defmodule Otis.Mixfile do
  use Mix.Project

  def project do
    [app: :otis,
     version: "0.0.1",
     build_path: "../../_build",
     # config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     consolidate_protocols: Mix.env != :test,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:porcelain, :logger, :dnssd, :monotonic, :enm, :sqlite_ecto, :ecto, :peel],
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
    [
      {:porcelain, "~> 2.0"},
      {:dnssd, github: "benoitc/dnssd_erlang"},
      {:poolboy, "~> 1.4"},
      {:monotonic, github: "magnetised/monotonic.ex"},
      {:enm, github: "basho/enm" },
      {:erlsom, github: "willemdj/erlsom"},
      {:uuid, "~> 1.1"},
      {:sqlite_ecto, "~> 1.0.0"},
      {:ecto, "~> 1.0"},
      {:faker, "~> 0.5", only: :test},
    ]
  end
end
