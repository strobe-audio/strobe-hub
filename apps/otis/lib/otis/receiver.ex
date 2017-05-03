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
    update_closing(receiver, extract_params(values))
  end

  defp update_closing(receiver, values) do
    receiver = Enum.reduce([:ctrl, :data], receiver, &update_closing(&1, &2, values))
    struct(receiver, values)
  end
  defp update_closing(type, receiver, values) do
    case Keyword.get(values, type) do
      nil ->
        receiver
      {_pid, _sock} ->
        Map.get(receiver, type) |> disconnect
        Map.put(receiver, type, nil)
    end
  end

  def disconnect(%R{data: data, ctrl: ctrl} = receiver) do
    disconnect(data)
    disconnect(ctrl)
    receiver
  end
  def disconnect({pid, _socket}) when is_pid(pid) do
    try do
      GenServer.cast(pid, :disconnect)
    catch
      :exit, _ -> :ok
    end
  end
  def disconnect(nil), do: nil

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
  def matches_pid?(%R{data: data, ctrl: ctrl, latch: lpid}, pid) do
    _match_pid?(data, pid) || _match_pid?(ctrl, pid) || _match_pid?(lpid, pid)
  end
  def _match_pid?(nil, _pid), do: false
  def _match_pid?({cpid, _}, pid), do: _match_pid?(cpid, pid)
  def _match_pid?(cpid, pid) when is_pid(cpid), do: cpid == pid
  def _match_pid?(_, _), do: false

  @doc ~S"""
  Set the volume and multiplier simultaneously.
  """
  def volume(receiver, volume, multiplier) do
    set_volume(receiver, Otis.sanitize_volume(volume), Otis.sanitize_volume(multiplier))
  end

  defp set_volume(%R{ctrl: nil} = receiver, _volume, _multiplier) do
    Logger.warn "Attempt to set volume of receiver with no control connection #{receiver}"
    receiver
  end
  defp set_volume(%R{ctrl: {pid, _socket}} = receiver, volume, multiplier) do
    Otis.Receivers.ControlConnection.set_volume(pid, volume, multiplier)
    receiver
  end

  def volume(receiver, volume) do
    set_volume(receiver, Otis.sanitize_volume(volume))
  end

  defp set_volume(%R{ctrl: nil} = receiver, _volume) do
    Logger.warn "Attempt to set volume of receiver with no control connection #{receiver}"
    receiver
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

  @doc """
  Maps linear volume 0.0 <= v <= 1.0 to exponential version based on
  calculations here: https://www.dr-lex.be/info-stuff/volumecontrols.html
  """
  def perceptual_volume(volume) do
    case volume do
      0.0 -> 0.0
      1.0 -> 1.0
      v when v < 0.1 -> logarithmic_volume(v) * (v * 10)
      v -> logarithmic_volume(v)
    end |> Otis.sanitize_volume
  end

  @exponent_factor :math.log(1000.0)

  defp logarithmic_volume(volume) do
    0.001 * :math.exp(volume * @exponent_factor)
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
    Otis.Receivers.Channels.add_receiver(receiver, channel)
  end

  @doc ~S"""
  Configure the receiver from the db and join it to the channel
  """
  def configure_and_join_channel(nil, _state, _channel) do
    Logger.warn "Configuring nil receiver"
  end
  def configure_and_join_channel(_receiver, _state, nil) do
    Logger.warn "Configuring receiver to join non-existant channel"
  end
  def configure_and_join_channel(receiver, state, channel) do
    mute(receiver, state.muted)
    set_volume(receiver, state.volume, channel.volume)
    join_channel(receiver, channel)
  end

  def configure(%R{ctrl: {pid, _socket}}, settings) do
    Otis.Receivers.ControlConnection.configure(pid, settings)
  end
  def configure(_receiver, _settings) do
  end

  @stop_command <<"STOP">>

  def stop_command, do: @stop_command

  def stop(receiver) do
    send_data(receiver, @stop_command)
    # send_command(receiver, "stop")
  end

  def ip_address({_id, receiver}), do: ip_address(receiver)
  def ip_address(%R{ctrl: {_pid, socket}}) do
    _ip_address(socket)
  end
  def ip_address(%R{data: {_pid, socket}}) do
    _ip_address(socket)
  end
  def ip_address(_receiver), do: :error

  defp _ip_address(socket) do
    {:ok, {addr, _port}} = :inet.peername(socket)
    {:ok, addr}
  end

  def send_packets(%R{data: {pid, _socket}}, packets) do
    GenServer.cast(pid, {:packets, packets})
  end
  def send_packets(%R{data: nil}, _packets) do
  end

  def send_data(%{data: {pid, _socket}}, data) do
    GenServer.cast(pid, {:data, data})
  end
  def send_data(%{data: nil}, _data) do
  end

  def send_command(%{ctrl: {pid, _socket}}, command) do
    GenServer.cast(pid, {:command, command})
  end
  def send_command(%{ctrl: nil}, _command) do
  end

  def mute(%R{data: nil} = receiver, _muted) do
    receiver
  end
  def mute(%R{data: {pid, _socket}} = receiver, muted) do
    if muted do
      stop(receiver)
    end
    GenServer.cast(pid, {:mute, muted})
    receiver
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
