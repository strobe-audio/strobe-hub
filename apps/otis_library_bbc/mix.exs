defmodule HLS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :otis_library_bbc,
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
    [extra_applications: [:logger], mod: {BBC, []}]
  end

  defp deps do
    [
      {:httpoison, "~> 1.0"},
      {:poison, "~> 3.0"},
      {:otis_library, in_umbrella: true}
    ]
  end
end
