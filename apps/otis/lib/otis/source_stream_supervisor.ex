defmodule Otis.SourceStreamSupervisor do
  use Supervisor

  @supervisor_name Otis.SourceStreamSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start(source, playback_position) do
    start(@supervisor_name, source, playback_position)
  end

  def start(supervisor, source, playback_position) do
    Supervisor.start_child(supervisor, [source, playback_position])
  end

  def init(:ok) do
    children = [
      worker(Otis.SourceStream, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
