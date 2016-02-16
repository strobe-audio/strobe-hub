defmodule Peel do
  use     Application
  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Peel.Worker, [arg1, arg2, arg3]),
      worker(Peel.Repo, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Peel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def scan([]) do
    Logger.info("Scan done...")
  end
  def scan([path|paths]) do
    Logger.info("Starting scan of #{ inspect path}")
    Peel.Scanner.start(path)
    scan(paths)
  end
end
