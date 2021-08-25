defmodule Otis.Pipeline.Streams do
  use Supervisor

  @supervisor_name Otis.Pipeline.Streams
  @namespace Otis.Pipeline.StreamRegistry

  def name(rendition_id) do
    {:via, Registry, {@namespace, rendition_id}}
  end

  def start_stream(rendition_id, config) do
    name = name(rendition_id)
    with {:ok, _pid} <- DynamicSupervisor.start_child(@supervisor_name, {Otis.Pipeline.Buffer, [name, rendition_id, config]}) do
      {:ok, name}
    end
  end

  def streams do
    Supervisor.which_children(@supervisor_name)
  end

  def start_link(_args \\ []) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: @supervisor_name},
      {Registry, keys: :unique, name: @namespace},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
