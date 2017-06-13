defmodule Strobe.Server.Application do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false


    # Define workers and child supervisors to be supervised
    children = [
      worker(Strobe.Server.Events, []),
      worker(Strobe.Server.Startup, []),
      worker(Strobe.Server.Ethernet, ["eth0"]),
      worker(Strobe.Server.Ntp, []),
      worker(Strobe.Server.Fs, [["/dev/sda1", "/state"]], restart: :transient),
      worker(Strobe.Server.Dbus, []),
      worker(Strobe.Server.Avahi, ["eth0"]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Strobe.Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
