defmodule ExternalProcess.Mixfile do
  use Mix.Project

  def project do
    [
      app: :external_process,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps()
    ]
  end

  def application do
    [mod: {ExternalProcess, []}, extra_applications: [:logger]]
  end

  defp deps do
    [{:porcelain, github: "strobe-audio/porcelain"}]
  end
end
