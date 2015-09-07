defmodule Janis do
  def start(_type, _args) do
    IO.inspect [:Janis, :start]
    Janis.Supervisor.start_link
  end

  def milliseconds do
    :erlang.monotonic_time(:milli_seconds)
  end
  def microseconds do
    :erlang.monotonic_time(:micro_seconds)
  end
end
