defmodule Otis do
  use Application

  def config do
    Otis.Pipeline.config()
  end

  def start(_type, _args) do
    Otis.Supervisor.start_link(config())
  end

  def init(_args) do
    :ok
  end

  def uuid do
    UUID.uuid4()
  end

  def sanitize_volume(volume) when is_integer(volume), do: sanitize_volume(volume + 0.0)
  def sanitize_volume(volume) when volume > 1.0, do: 1.0
  def sanitize_volume(volume) when volume < 0.0, do: 0.0
  def sanitize_volume(volume), do: volume

  def start_phase(:run_migrations, _start_type, _args) do
    Otis.State.Migrator.run()
  end
end
