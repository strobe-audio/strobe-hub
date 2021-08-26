defmodule Elvis do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    startup =
      case Mix.env() do
        :test -> []
        _env -> [Otis.Startup]
      end

    children =
      [
        {Phoenix.PubSub, name: Elvis.PubSub},
        {Elvis.Endpoint, []},
        {Elvis.Events.Broadcast, []},
        {Elvis.Events.Startup, []}
        # XXX: Needs to be last
      ] ++ startup

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elvis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Elvis.Endpoint.config_change(changed, removed)
    :ok
  end
end
