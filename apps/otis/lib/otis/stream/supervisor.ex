defmodule Otis.StreamSupervisor do
  use Supervisor

  @supervisor __MODULE__
  @stream_module Otis.Channel.BufferedStream

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def start_stream(id, source_list, buffer_seconds, stream_bytes_per_step, interval_ms) do
    Supervisor.start_child(@supervisor, [id, source_list, buffer_seconds, stream_bytes_per_step, interval_ms])
    {:ok, name(id)}
  end

  def name(id) do
    {:via, :gproc, {:n, :l, {@stream_module, id}}}
  end

  def init(:ok) do
    children = [
      worker(@stream_module, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

