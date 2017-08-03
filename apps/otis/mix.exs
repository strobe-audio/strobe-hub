defmodule Otis.Mixfile do
  use Mix.Project

  def project do
    [app: :otis,
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

  def application do
    [extra_applications: [:logger],
     mod: {Otis, []},
     included_applications: included_applications(Mix.env),
     env: env(),
    ]
  end

  defp included_applications(:test), do: []
  defp included_applications(_env) do
    [:dnssd,
    ]
  end

  def env do
    [receiver_logger: [addr: {224, 0, 0, 224}, port: 9999]]
  end

  defp deps do
    [{:poolboy, "~> 1.4"},
     {:monotonic, github: "magnetised/monotonic.ex"},
     {:erlsom, github: "willemdj/erlsom"},
     {:uuid, "~> 1.1"},
     {:sqlite_ecto, github: "magnetised/sqlite_ecto"},
     {:ecto, "~> 1.0"},
     {:ranch, "~> 1.0", [optional: false, hex: :ranch, manager: :rebar]},
     {:otis_library, in_umbrella: true},
     {:external_process, in_umbrella: true},
     {:strobe_events, in_umbrella: true},
     {:nerves_ssdp_server, "~> 0.2.1"},
     {:gproc, "~> 0.5.0"},
     {:mdns, "~> 0.1.5"},
     {:gen_stage, "~> 0.12"},
    ] ++ deps(Mix.env)
  end

  defp deps(:test), do: []
  defp deps(_env) do
    [{:dnssd, github: "benoitc/dnssd_erlang", manager: :rebar, runtime: false},
    ]
  end
end