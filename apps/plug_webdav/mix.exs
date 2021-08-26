defmodule Plug.WebDAV.Mixfile do
  use Mix.Project

  def project do
    [
      app: :plug_webdav,
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
    [extra_applications: [:logger], mod: {Plug.WebDAV.Application, []}]
  end

  defp deps do
    [
      {:plug, "~> 1.7"},
      {:cowboy, "~> 2.0"},
      {:sweet_xml, "~> 0.6.5"},
      {:mime, "~> 1.1"},
      {:timex, "~> 3.0", only: :test},
      {:uuid, "~> 1.1"}
    ]
  end
end
