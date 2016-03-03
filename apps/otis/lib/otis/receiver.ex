defmodule Otis.Receiver do
  @moduledoc ~S"""
  Represents a receiver with an id, control and data connections.
  """

  require Logger
  alias   __MODULE__, as: R

  defstruct [:id, :data, :ctrl, :latency, :pid]


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

  def equal?(receiver1, receiver2) do
    receiver1.id == receiver2.id
  end

  @doc ~S"""
  An alive receiver has an id, and both a data & control connection
  """
  def alive?(%R{id: id, data: data, ctrl: ctrl})
  when is_binary(id) and not is_nil(data) and not is_nil(ctrl) do
    true
  end
  def alive?(_receiver) do
    false
  end

  @doc ~S"""
  An zombie receiver still has one valid connection, either data or control
  """
  def zombie?(%R{id: id, data: data, ctrl: ctrl})
  when is_binary(id) and (not(is_nil(data)) or not(is_nil(ctrl))) do
    true
  end
  def zombie?(_receiver) do
    false
  end

  @doc ~S"""
  A dead receiver has neither a data nor control connection
  """
  def dead?(%R{data: data, ctrl: ctrl})
  when (is_nil(data) and is_nil(ctrl)) do
    true
  end
  def dead?(_receiver) do
    false
  end

  @doc ~S"""
  Monitor the receiver by monitoring both of the connections.
  """
  def monitor(%R{data: {data_pid, _}, ctrl: {ctrl_pid, _}}) do
    data_ref = Process.monitor(data_pid)
    ctrl_ref = Process.monitor(ctrl_pid)
    {data_ref, ctrl_ref}
  end

  @doc ~S"""
  Processes monitoring receivers will get a :DOWN message with a pid. This
  is a convenience function to pull the receiver matching that pid from a list.
  """
  def matching_pid(receivers, pid) do
    receivers |> Enum.find(&matches_pid?(&1, pid))
  end

  @doc false
  def matches_pid?(%R{data: {dpid, _}, ctrl: {cpid, _}}, pid) do
    (dpid == pid) || (cpid == pid)
  end

  @doc ~S"""
  Set the volume and multiplier simultaneously.
  """
  def volume(receiver, volume, multiplier) do
    set_volume(receiver, Otis.sanitize_volume(volume), Otis.sanitize_volume(multiplier))
  end

  defp set_volume(%R{ctrl: {pid, _socket}} = receiver, volume, multiplier) do
    Otis.Receivers.ControlConnection.set_volume(pid, volume, multiplier)
    receiver
  end

  def volume(receiver, volume) do
    set_volume(receiver, Otis.sanitize_volume(volume))
  end

  defp set_volume(%R{ctrl: {pid, _socket}} = receiver, volume) do
    Otis.Receivers.ControlConnection.set_volume(pid, volume)
    receiver
  end

  def volume(receiver) do
    get_volume(receiver)
  end

  defp get_volume(%R{ctrl: {pid, _socket}}) do
    Otis.Receivers.ControlConnection.get_volume(pid)
  end

  @doc ~S"""
  Volume multiplier is the way through which the zones control all of
  their receivers' volumes.

  Setting the volume multiplier sends volume control messages to change the
  actual receiver's volume, but doesn't persist the calculated volume to the
  db. Only the `volume` setting is persisted.

  See the corresponding logic in `Otis.Receivers.ControlConnection`.
  """
  def volume_multiplier(receiver, multiplier) do
    set_volume_multiplier(receiver, Otis.sanitize_volume(multiplier))
  end

  defp set_volume_multiplier(%R{ctrl: {pid, _socket}}, multiplier) do
    Otis.Receivers.ControlConnection.set_volume_multiplier(pid, multiplier)
  end

  def volume_multiplier(receiver) do
    get_volume_multiplier(receiver)
  end

  defp get_volume_multiplier(%R{ctrl: {pid, _socket}}) do
    Otis.Receivers.ControlConnection.get_volume_multiplier(pid)
  end

  # TODO: what else do we need to do here? actions remaining
  # - tell the zone we belong to it, so the zone:
  #   - adds the receiver to its list (for volume changes)
  #   - adds the receiver to its socket (for audio changes)
  # - emit some zone change event (for persistence)
  #
  @doc ~S"""
  Change the zone for an already running & configured receiver
  """
  def join_zone(receiver, zone) do
    Otis.Zone.add_receiver(zone, receiver)
  end

  @doc ~S"""
  Configure the receiver from the db and join it to the zone
  """
  def configure_and_join_zone(receiver, state, zone) do
    set_volume(receiver, state.volume, Otis.Zone.volume!(zone))
    join_zone(receiver, zone)
  end

  def configure(receiver, %Otis.State.Receiver{volume: volume} = _config) do
    volume(receiver, volume)
  end

  def send_data(%{data: {_pid, socket}} = receiver, data) do
    case :gen_tcp.send(socket, data) do
      {:error, _} = error ->
        Logger.warn "Error #{ inspect error }sending data to receiver #{ inspect receiver } #{ inspect data }"
        error
      ok -> ok
    end
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
