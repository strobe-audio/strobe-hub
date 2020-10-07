defmodule Strobe.Events.Mixfile do
  use Mix.Project

  def project do
    [
      app: :strobe_events,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Strobe.Events.Application, []}]
  end

  defp deps do
    [{:gen_stage, "~> 1.0"}]
  end
end
