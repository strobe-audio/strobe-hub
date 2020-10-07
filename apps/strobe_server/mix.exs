defmodule Strobe.Server.Mixfile do
  use Mix.Project

  # Default to "host" target to prevent this app doing anything in most
  # circumstances, use `MIX_TARGET=rpi3` for nerves-related activity
  @target System.get_env("MIX_TARGET") || "host"

  Mix.shell().info([
    :green,
    """
    Env
      MIX_TARGET:   #{@target}
      MIX_ENV:      #{Mix.env()}
    """,
    :reset
  ])

  def project do
    [
      app: :strobe_server,
      version: "0.1.0",
      elixir: "~> 1.7.0",
      target: @target,
      archives: [nerves_bootstrap: "~> 0.3.0"],
      deps_path: "../../deps/#{@target}",
      build_path: "../../_build/#{@target}",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(@target),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application, do: application(@target)

  # Specify target specific application configurations
  # It is common that the application start function will start and supervise
  # applications which could cause the host to fail. Because of this, we only
  # invoke StrobeServer.start/2 when running on a target.
  def application("host") do
    [extra_applications: [:logger]]
  end

  def application(_target) do
    [
      mod: {Strobe.Server.Application, []},
      applications: [
        :gen_stage,
        :nerves_networking,
        :nerves_network_interface
      ],
      extra_applications: [:logger],
      included_applications: [
        :esqlite,
        :elvis,
        :otis,
        :peel,
        :otis_library_bbc,
        :otis_library_upnp,
        :otis_library_airplay
      ]
    ]
  end

  def deps do
    deps(@target)
  end

  # Specify target specific dependencies
  def deps("host"), do: []

  def deps(target) do
    [
      {:nerves_runtime, "~> 0.1.0", only: :nerves},
      {:"nerves_system_#{target}", "~> 0.11.0", runtime: false, only: :nerves},
      {:nerves, "~> 0.5.0", runtime: false, only: :nerves},
      {:gen_stage, "~> 0.12", only: :nerves},
      {:nerves_networking, github: "nerves-project/nerves_networking", only: :nerves},
      {:nerves_network_interface, "~> 0.4.0", only: :nerves},
      {:elvis, in_umbrella: true, only: :nerves}
    ]
  end

  # We do not invoke the Nerves Env when running on the Host
  def aliases("host"), do: []

  def aliases(_target) do
    [
      "deps.precompile": ["nerves.precompile", "deps.precompile"],
      "deps.loadpaths": ["deps.loadpaths", "nerves.loadpaths"]
    ]
  end
end
