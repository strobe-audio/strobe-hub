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
  when (is_nil(data_socket) and is_nil(ctrl_socket))
  do
    true
  end
  def dead?(_receiver) do
    false
  end

  def volume(receiver, volume, multiplier) do
    set_volume(receiver, Otis.sanitize_volume(volume), Otis.sanitize_volume(multiplier))
  end

  defp set_volume(%R{ctrl_socket: ctrl_socket} = receiver, volume, multiplier) do
    Otis.ReceiverSocket.ControlConnection.set_volume(ctrl_socket, volume, multiplier)
    receiver
  end

  def volume(receiver, volume) do
    set_volume(receiver, Otis.sanitize_volume(volume))
  end

  defp set_volume(%R{ctrl_socket: ctrl_socket} = receiver, volume) do
    Otis.ReceiverSocket.ControlConnection.set_volume(ctrl_socket, volume)
    receiver
  end

  def volume(receiver) do
    get_volume(receiver)
  end

  defp get_volume(%R{ctrl_socket: ctrl_socket}) do
    Otis.ReceiverSocket.ControlConnection.get_volume(ctrl_socket)
  end

  @doc """
  Volume multiplier is the way through which the zones control all of
  their receivers' volumes.

  Setting the volume multiplier sends volume control messages to change the
  actual receiver's volume, but doesn't persist the calculated volume to the
  db. Only the `volume` setting is persisted.

  See the corresponding logic in `Otis.ReceiverSocket.ControlConnection`.
  """
  def volume_multiplier(receiver, multiplier) do
    set_volume_multiplier(receiver, Otis.sanitize_volume(multiplier))
  end

  defp set_volume_multiplier(%R{ctrl_socket: ctrl_socket}, multiplier) do
    Otis.ReceiverSocket.ControlConnection.set_volume_multiplier(ctrl_socket, multiplier)
  end

  def volume_multiplier(receiver) do
    get_volume_multiplier(receiver)
  end

  defp get_volume_multiplier(%R{ctrl_socket: ctrl_socket}) do
    Otis.ReceiverSocket.ControlConnection.get_volume_multiplier(ctrl_socket)
  end

  def join_zone(receiver, zone, configuration) do
    # need to actually join the zone here
    # the receivers need a set_volume/3 function
    # set_volume(receiver, receiver_volume, zone_volume)
    # so that the receiver volume setting can be persisted
    # without any effect from its containing zone
    IO.inspect [:join_zone, receiver, zone, configuration]
  end

  def configure(receiver, %Otis.State.Receiver{volume: volume} = _config) do
    volume(receiver, volume)
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
