defmodule Otis.Receiver do
  @moduledoc ~S"""
  Represents a receiver with an id, control and data connections.
  """

  require Logger
  alias   __MODULE__, as: R

  defstruct [:id, :data, :ctrl, :latency, :latch]

  def new(values) do
    %R{} |> struct(extract_params(values)) |> create_latch()
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

  @latch_exit_signal :exit

  def create_latch(receiver) do
    %R{ receiver | latch: start_latch_process() }
  end

  def release_latch(nil), do: nil
  def release_latch(%R{latch: pid} = receiver) do
    send(pid, @latch_exit_signal)
    create_latch(receiver)
  end

  defp start_latch_process do
    pid = spawn(fn ->
      receive do
        @latch_exit_signal -> nil
      end
    end)
    Process.monitor(pid)
    pid
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
  Monitor the receiver by monitoring both of the connections and the latch
  process.
  """
  def monitor(%R{data: {data_pid, _}, ctrl: {ctrl_pid, _}, latch: latch_pid}) do
    data_ref = Process.monitor(data_pid)
    ctrl_ref = Process.monitor(ctrl_pid)
    latch_ref = Process.monitor(latch_pid)
    {data_ref, ctrl_ref, latch_ref}
  end

  @doc ~S"""
  Processes monitoring receivers will get a :DOWN message with a pid. This
  is a convenience function to pull the receiver matching that pid from a list.
  """
  def matching_pid(receivers, pid) do
    receivers |> Enum.find(&matches_pid?(&1, pid))
  end

  @doc false
  def matches_pid?({id, receiver}, pid) when is_binary(id) do
    matches_pid?(receiver, pid)
  end
  def matches_pid?(%R{data: {dpid, _}, ctrl: {cpid, _}, latch: lpid}, pid) do
    (dpid == pid) || (cpid == pid) || (lpid == pid)
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
  Volume multiplier is the way through which the channels control all of
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
  # - tell the channel we belong to it, so the channel:
  #   - adds the receiver to its list (for volume changes)
  #   - adds the receiver to its socket (for audio changes)
  # - emit some channel change event (for persistence)
  #
  @doc ~S"""
  Change the channel for an already running & configured receiver
  """
  def join_channel(receiver, channel) do
    Otis.Receivers.Sets.add_receiver(receiver, channel)
  end

  @doc ~S"""
  Configure the receiver from the db and join it to the channel
  """
  def configure_and_join_channel(receiver, state, channel) do
    set_volume(receiver, state.volume, channel.volume)
    join_channel(receiver, channel)
  end

  def configure(receiver, %Otis.State.Receiver{volume: volume} = _config) do
    volume(receiver, volume)
  end

  @stop_command <<"STOP">>

  def stop_command, do: @stop_command

  def stop(receiver) do
    send_data(receiver, @stop_command)
    # send_command(receiver, "stop")
  end

  def send_data(%{data: {pid, _socket}}, data) do
    GenServer.cast(pid, {:data, data})
  end
  def send_command(%{ctrl: {pid, _socket}}, command) do
    GenServer.cast(pid, {:command, command})
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
