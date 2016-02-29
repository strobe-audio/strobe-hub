defmodule Otis.Receiver2 do
  defstruct [:id, :data_socket, :ctrl_socket, :latency]

  alias __MODULE__, as: R

  def new(values) do
    struct(%R{}, extract_params(values))
  end

  def update(receiver, values) do
    struct(receiver, extract_params(values))
  end

  @doc "An alive receiver has an id, and both a data & control connection"
  def alive?(%R{id: id, data_socket: data_socket, ctrl_socket: ctrl_socket})
  when is_binary(id) and not is_nil(data_socket) and not is_nil(ctrl_socket) do
    true
  end
  def alive?(_receiver) do
    false
  end

  @doc "An zombie receiver still has one valid connection, either data or control"
  def zombie?(%R{id: id, data_socket: data_socket, ctrl_socket: ctrl_socket})
  when is_binary(id) and (not(is_nil(data_socket)) or not(is_nil(ctrl_socket))) do
    true
  end
  def zombie?(_receiver) do
    false
  end

  @doc "A dead receiver has neither a data nor control connection"
  def dead?(%R{data_socket: data_socket, ctrl_socket: ctrl_socket})
  when (is_nil(data_socket) and is_nil(ctrl_socket)) do
    true
  end
  def dead?(_receiver) do
    false
  end

  def volume(receiver, volume) do
    set_volume(receiver, Otis.sanitize_volume(volume))
  end

  defp set_volume(%R{ctrl_socket: ctrl_socket}, volume) do
    Otis.ReceiverSocket.ControlConnection.set_volume(ctrl_socket, volume)
  end

  def volume(receiver) do
    get_volume(receiver)
  end

  defp get_volume(%R{ctrl_socket: ctrl_socket}) do
    Otis.ReceiverSocket.ControlConnection.get_volume(ctrl_socket)
  end

  def extract_params(values) do
    Keyword.pop(values, :params) |> merge_params
  end

  defp merge_params({nil, values}) do
    values
  end
  defp merge_params({params, values}) do
    case Map.get(params, "latency") do
      nil     -> values
      latency -> Keyword.merge(values, [latency: latency])
    end
  end

end
