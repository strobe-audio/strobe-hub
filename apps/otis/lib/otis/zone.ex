defmodule Otis.Zone do

  defstruct name:          "A Zone",
            id:            nil,
            source_stream: nil,
            receivers:     [],
            state:         :stop,
            broadcaster:   nil,
            audio_stream:  nil

  use GenServer

  alias Otis.Zone, as: Zone

  def start_link(id, name) do
    start_link(id, name, Otis.SourceStream.Array.empty)
  end

  def start_link(id, name, {:ok, source_stream }) do
    start_link(id, name, source_stream)
  end

  def start_link(id, name, source_stream) do
    GenServer.start_link(__MODULE__, %Zone{ id: id, name: name, source_stream: source_stream, broadcaster: nil })
  end

  def init(%Zone{ source_stream: source_stream } = zone) do
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, Otis.stream_bytes_per_step)
    {:ok, %Zone{ zone | audio_stream: audio_stream }}
  end

  def id(zone) do
    GenServer.call(zone, :id)
  end

  def name(zone) do
    GenServer.call(zone, :name)
  end

  def receivers(zone) do
    GenServer.call(zone, :receivers)
  end

  def add_receiver(zone, receiver) do
    GenServer.call(zone, {:add_receiver, receiver})
  end

  def remove_receiver(zone, receiver) do
    GenServer.call(zone, {:remove_receiver, receiver})
  end

  def state(zone) do
    GenServer.call(zone, :get_state)
  end

  def play_pause(zone) do
    GenServer.call(zone, :play_pause)
  end

  def source_stream(zone) do
    GenServer.call(zone, :get_source_stream)
  end

  def audio_stream(zone) do
    GenServer.call(zone, :get_audio_stream)
  end

  # Things we can do to zones:
  # - list receivers
  # - add receiver
  # - remove receiver
  # - change source stream
  # - on the attached source stream:
  #   - add/remove sources
  #   - re-order sources
  #   - change position in source stream (skip track)
  # - get playing state
  # - start / stop
  # - change volume (?)

  def handle_call(:id, _from, %Zone{id: id} = zone) do
    {:reply, {:ok, id}, zone}
  end

  def handle_call(:name, _from, %Zone{name: name} = zone) do
    {:reply, {:ok, name}, zone}
  end

  def handle_call(:receivers, _from, %Zone{receivers: receivers} = zone) do
    {:reply, {:ok, receivers}, zone}
  end

  def handle_call({:add_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
    {:reply, :ok, %Zone{ zone | receivers: ( receivers ++ [receiver] ) }}
  end

  def handle_call({:remove_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
    {:reply, :ok, %Zone{ zone | receivers: List.delete(receivers, receiver) }}
  end

  def handle_call(:play_pause, _from, zone) do
    zone = %Zone{state: state} = toggle_state(zone) |> change_state
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_state, _from, %Zone{state: state} = zone) do
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_audio_stream, _from, %Zone{audio_stream: audio_stream} = zone) do
    {:reply, {:ok, audio_stream}, zone}
  end

  def handle_call(:get_source_stream, _from, %Zone{source_stream: source_stream} = zone) do
    {:reply, {:ok, source_stream}, zone}
  end

  def handle_cast(:broadcast, %Zone{ state: :play, audio_stream: audio_stream, receivers: receivers} = zone) do
    # IO.inspect ["zone broadcast", :play, :erlang.monotonic_time(:milli_seconds), audio_stream]
    zone = broadcast_frame(Otis.AudioStream.frame(audio_stream), receivers, zone)
    {:noreply, zone}
  end

  def broadcast_frame({:ok, data}, [r | t], zone) do
    # IO.inspect [:send, r, data]
    send(r, {:frame, data})
    broadcast_frame({:ok, data}, t, zone)
  end

  def broadcast_frame({:ok, data}, [], zone) do
    zone
  end

  def broadcast_frame(:done,  zone) do
    IO.inspect [:audio_stream, :done]
    # set zone state to stop
    zone
  end

  def handle_cast(:broadcast, %Zone{ state: :stop} = zone) do
    IO.inspect ["zone broadcast", :stop]
    {:noreply, zone}
  end

  defp toggle_state(%Zone{state: :play} = zone) do
    %Zone{ zone | state: :stop }
  end

  defp toggle_state(%Zone{state: :stop} = zone) do
    %Zone{ zone | state: :play }
  end

  defp change_state(%Zone{state: :play} = zone) do
    IO.inspect :launch
    IO.inspect self
    {:ok, pid } = Otis.Broadcaster.start_link(self, Otis.stream_interval_ms)
    %Zone{ zone | broadcaster: pid }
  end

  defp change_state(%Zone{state: :stop, broadcaster: nil} = zone) do
    IO.inspect :no_Broadcaster
    zone
  end

  defp change_state(%Zone{state: :stop, broadcaster: broadcaster} = zone) do
    IO.inspect [:this_stop, broadcaster]
    Otis.Broadcaster.stop(broadcaster)
    %Zone{ zone | broadcaster: nil }
  end
end
