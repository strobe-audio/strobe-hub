defmodule Otis.Receiver2 do
  @moduledoc "Represents a receiver"

  defstruct [:id, :data, :ctrl, :latency]

  alias __MODULE__, as: R

  def new(values) do
    struct(%R{}, extract_params(values))
  end

  def update(receiver, values) do
    struct(receiver, extract_params(values))
  end

  def id!(receiver) do
    receiver.id
  end

  def latency!(receiver) do
    receiver.latency
  end

  @doc "An alive receiver has an id, and both a data & control connection"
  def alive?(%R{id: id, data: data, ctrl: ctrl})
  when is_binary(id) and not is_nil(data) and not is_nil(ctrl) do
    true
  end
  def alive?(_receiver) do
    false
  end

  @doc "An zombie receiver still has one valid connection, either data or control"

  def zombie?(%R{id: id, data: data, ctrl: ctrl})
  when is_binary(id) and (not(is_nil(data)) or not(is_nil(ctrl))) do
    true
  end
  def zombie?(_receiver) do
    false
  end

  @doc "A dead receiver has neither a data nor control connection"

  def dead?(%R{data: data, ctrl: ctrl})
  when (is_nil(data) and is_nil(ctrl)) do
    true
  end
  def dead?(_receiver) do
    false
  end

  def volume(receiver, volume, multiplier) do
    set_volume(receiver, Otis.sanitize_volume(volume), Otis.sanitize_volume(multiplier))
  end

  defp set_volume(%R{ctrl: {pid, _socket}} = receiver, volume, multiplier) do
    Otis.ReceiverSocket.ControlConnection.set_volume(pid, volume, multiplier)
    receiver
  end

  def volume(receiver, volume) do
    set_volume(receiver, Otis.sanitize_volume(volume))
  end

  defp set_volume(%R{ctrl: {pid, _socket}} = receiver, volume) do
    Otis.ReceiverSocket.ControlConnection.set_volume(pid, volume)
    receiver
  end

  def volume(receiver) do
    get_volume(receiver)
  end

  defp get_volume(%R{ctrl: {pid, _socket}}) do
    Otis.ReceiverSocket.ControlConnection.get_volume(pid)
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

  defp set_volume_multiplier(%R{ctrl: {pid, _socket}}, multiplier) do
    Otis.ReceiverSocket.ControlConnection.set_volume_multiplier(pid, multiplier)
  end

  def volume_multiplier(receiver) do
    get_volume_multiplier(receiver)
  end

  defp get_volume_multiplier(%R{ctrl: {pid, _socket}}) do
    Otis.ReceiverSocket.ControlConnection.get_volume_multiplier(pid)
  end

  # TODO: what else do we need to do here? actions remaining
  # - tell the zone we belong to it, so the zone:
  #   - adds the receiver to its list (for volume changes)
  #   - adds the receiver to its socket (for audio changes)
  # - emit some zone change event (for persistence)
  #
  @doc "Change the zone for an already running & configured receiver"
  def join_zone(receiver, zone) do
    Otis.Zone.add_receiver(zone, receiver)
  end
  @doc "Configure the receiver from the db and join it to the zone"
  def configure_and_join_zone(receiver, state, zone) do
    set_volume(receiver, state.volume, Otis.Zone.volume!(zone))
    join_zone(receiver, zone)
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
