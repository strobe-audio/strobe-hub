defmodule Otis.Pipeline.Streams do
  use Supervisor

  @supervisor_name Otis.Pipeline.Streams
  @namespace Otis.Pipeline.StreamRegistry

  def namespace, do: @namespace

  def name(rendition_id) do
    {:via, Registry, {@namespace, rendition_id}}
  end

  def start_stream(rendition_id, config) do
    name = name(rendition_id)
    {:ok, _pid} = Supervisor.start_child(@supervisor_name, [name, rendition_id, config])
    {:ok, name}
  end

  def streams do
    Supervisor.which_children(@supervisor_name)
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def init(:ok) do
    children = [
      worker(Otis.Pipeline.Buffer, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
