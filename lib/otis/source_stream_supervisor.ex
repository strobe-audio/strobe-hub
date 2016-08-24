defmodule Otis.SourceStreamSupervisor do
  use Supervisor

  @supervisor Otis.SourceStreamSupervisor
  @stream_module Otis.SourceStream

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def start(id, source, playback_position) do
    {:ok, _pid} = Supervisor.start_child(@supervisor, [id, source, playback_position])
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
