defmodule Otis.AudioStream do
  @moduledoc """
  Transforms a source of sources into a byte stream chunked according to the
  bit rate of the desired audio stream
  """

  use     GenServer
  require Logger
  alias   Otis.Packet

  defmodule S do
    defstruct [
      :source_list,
      :packet,
      :stream,
      buffer:      <<>>,
      packet_size:  3528,
      state:       :stopped
    ]
  end

  def frame(pid) do
    GenServer.call(pid, :frame, 2_000)
  end

  def buffer(pid) do
    GenServer.call(pid, :buffer)
  end

  def start_link(source_list, packet_size) do
    GenServer.start_link(__MODULE__, %S{source_list: source_list, packet_size: packet_size})
  end

  def start_link(source_list) do
    GenServer.start_link(__MODULE__, %S{source_list: source_list})
  end

  def init(state) do
    {:ok, state}
  end

  # TODO: Do I need to implement this
  def handle_call(:buffer, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:frame, _from, %S{stream: nil, state: :stopped} = state) do
    state = %S{ state | state: :starting }
    {:frame, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  def handle_call(:frame, _from, state) do
    {:frame, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  def handle_call(:flush, _from, state) do
    if state.stream != nil do
       Otis.SourceStream.close(state.stream)
    end
    {:reply, :ok, %S{ state | stream: nil, state: :stopped, buffer: <<>> }}
  end

  def handle_call(:reset, _from, %S{stream: nil} = state) do
    {:reply, :ok, state}
  end
  def handle_call(:reset, _from, state) do
    Otis.SourceStream.pause(state.stream)
    {:reply, :ok, state}
  end

  def handle_call(:resume, _from, %S{stream: nil} = state) do
    {:reply, :resume, state}
  end
  def handle_call(:resume, _from, %S{stream: stream} = state) do
    reply = Otis.SourceStream.resume(stream)
    state = case reply do
      :resume -> state
      :flush -> %S{state | buffer: <<>>, state: :starting}
    end
    {:reply, reply, state}
  end

  def handle_cast({:skip, _id}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, {:shutdown, :done}} , state) do
    {:noreply, state}
  end
  def handle_info({:DOWN, _ref, :process, _pid, _reason} , state) do
    {:noreply, state}
  end

  defp audio_frame(%S{stream: nil, state: :starting} = state) do
    audio_frame(enumerate_source(state))
  end

  defp audio_frame(%S{ state: :stopped, packet: packet, buffer: buffer } = state)
  when byte_size(buffer) > 0 do
    state = %S{state | buffer: <<>> } |> update_packet
    {:frame, {:ok, Packet.attach(packet, buffer)}, state}
  end

  defp audio_frame(%S{ state: :stopped, buffer: buffer } = state)
  when byte_size(buffer) == 0 do
    {:frame, :stopped, %S{ state | stream: nil }}
  end

  defp audio_frame(%S{ stream: nil, buffer: buffer, packet_size: packet_size} = state)
  when byte_size(buffer) < packet_size do
    state |> enumerate_source |> audio_frame
  end

  defp audio_frame(%S{ stream: stream, buffer: buffer, packet_size: packet_size} = state)
  when byte_size(buffer) < packet_size do
    stream |> Otis.SourceStream.chunk |> append_and_send(state)
  end

  defp audio_frame(%S{ buffer: buffer, packet: packet, packet_size: packet_size } = state) do
    << data :: binary-size(packet_size), rest :: binary >> = buffer
    state = %S{ state | buffer: rest } |> update_packet
    {:frame, {:ok, Packet.attach(packet, data)}, state}
  end

  defp append_and_send({:ok, data}, %S{buffer: buffer } = state) do
    audio_frame(%S{ state | buffer: << buffer <> data >> })
  end

  defp append_and_send(:done, state) do
    try do
      Otis.SourceStream.close(state.stream)
    catch
      :exit, _ -> Logger.warn "Closing already closed source stream"
    end
    audio_frame(%S{state | stream: nil})
  end

  defp enumerate_source(%S{stream: nil} = state) do
    state |> next_source |> open_source |> use_stream(state)
  end
  defp enumerate_source(state) do
    state
  end

  defp next_source(state) do
    Otis.SourceList.next(state.source_list)
  end

  defp open_source(:done) do
    :done
  end
  defp open_source({:ok, {id, playback_position, source}}) do
    Otis.SourceStream.new(id, playback_position, source) |> monitor_source
  end

  defp monitor_source({:ok, _id, _playback_position, _duration, stream} = source) do
    monitor_stream_process(stream)
    source
  end
  defp monitor_stream_process(stream) when is_tuple(stream) do
    stream |> GenServer.whereis |> monitor_stream_process
  end
  defp monitor_stream_process(stream) when is_pid(stream) do
    Process.monitor(stream)
  end

  # TODO: use source needs the stream & id, *and* the playback position and
  # duration, *or* some object that will manage the playback progress every
  # packet we emit needs to be tagged with the {position, duration} tuple
  # so that the broadcaster can use that info to emit position information when
  # the packet has been played ( i.e. t >= packet timestamp )
  defp use_stream({:ok, id, playback_position, duration, stream}, state) do
    %S{ state | stream: stream } |> new_packet(id, playback_position, duration)
  end
  defp use_stream(:done, state) do
    %S{ state | state: :stopped }
  end

  defp new_packet(state, id, position, duration) do
    %S{ state | state: :playing, packet: Packet.new(id, position, duration, state.packet_size) }
  end

  defp update_packet(%S{packet: packet} = state) do
    %S{ state | packet: Packet.step(packet) }
  end
end
