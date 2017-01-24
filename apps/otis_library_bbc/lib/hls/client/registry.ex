defmodule HLS.Client.Registry do
  def via(id) do
    {:via, __MODULE__, id}
  end

  def register_name(id, pid) do
    id |> key |> :gproc.register_name(pid)
  end

  def unregister_name(id) do
    id |> key |> :gproc.unregister_name
  end

  def whereis_name(id) do
    id |> key |> :gproc.whereis_name
  end

  def send(id, msg) do
    id |> key |> :gproc.send(msg)
  end

  defp key(id) do
    {:n, :l, {__MODULE__, String.to_atom(id)}}
  end
end
