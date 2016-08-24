defmodule Elvis.Mixfile do
  use Mix.Project

  def project do
    [app: :elvis,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {Elvis, []},
     applications: [
       :phoenix,
       :phoenix_html,
       :cowboy,
       :logger,
       :otis,
       :peel,
       :hls
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
     {:cowboy, "~> 1.0"},
     # {:otis, path: "/Users/garry/Seafile/Peep/otis"},
     {:otis, git: "git@gitlab.com:magnetised/otis.git"},
     # {:peel, path: "/Users/garry/Seafile/Peep/peel"},
     {:peel, git: "git@gitlab.com:magnetised/peel.git"},
     # {:hls, path: "/Users/garry/Seafile/Peep/hls"},
     {:hls, git: "git@gitlab.com:magnetised/peep_bbc.git"},
     {:distillery, "~> 0.9", only: :dev},
   ]
  end
end
