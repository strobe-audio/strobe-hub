defmodule Otis.Channel do
  use     GenServer
  require Logger

  defmodule S do
    @moduledoc "The state struct for Channel processes"
    defstruct [
      id:          nil,
      playlist:    nil,
      state:       :pause,
      broadcaster: nil,
      volume:      1.0,
    ]
  end

  defstruct [:id, :pid]

  def id!(channel) do
    {:ok, id} = id(channel)
    id
  end

  def id(%__MODULE__{id: id}) do
    {:ok, id}
  end
  def id(channel) do
    GenServer.call(channel, :id)
  end

  def state(channel) do
    GenServer.call(channel, :get_state)
  end

  def play_pause(channel) do
    GenServer.call(channel, :play_pause)
  end

  def play(%__MODULE__{pid: pid}, playing) do
    play(pid, playing)
  end
  def play(channel, playing) do
    GenServer.call(channel, {:play, playing})
  end

  def playlist(channel) do
    GenServer.call(channel, :get_playlist)
  end

  def active_rendition(channel) do
    GenServer.call(channel, :active_rendition)
  end

  def volume!(channel) do
    {:ok, volume} = volume(channel)
    volume
  end

  def volume(%__MODULE__{pid: pid}) do
    volume(pid)
  end
  def volume(channel) do
    GenServer.call(channel, :volume)
  end

  def volume(%__MODULE__{pid: pid}, volume) do
    volume(pid, volume)
  end
  def volume(channel, volume) do
    GenServer.call(channel, {:volume, volume})
  end

  def playing?(%__MODULE__{pid: pid}) do
    playing?(pid)
  end
  def playing?(channel) do
    GenServer.call(channel, :playing)
  end

  @doc "Skip to the source with the given id"
  def skip(%__MODULE__{pid: pid}, source_id) do
    skip(pid, source_id)
  end
  def skip(channel, source_id) do
    GenServer.cast(channel, {:skip, source_id})
  end

  def clear(%__MODULE__{pid: pid}) do
    clear(pid)
  end
  def clear(channel) do
    GenServer.cast(channel, :clear)
  end

  def append(%__MODULE__{pid: pid}, sources) do
    append(pid, sources)
  end
  def append(channel, sources) do
    GenServer.call(channel, {:append_sources, sources})
  end

  def remove(%__MODULE__{pid: pid}, rendition_id) do
    remove(pid, rendition_id)
  end
  def remove(channel, rendition_id) do
    GenServer.call(channel, {:remove_rendition, rendition_id})
  end

  def start_link(channel, config, name) do
    GenServer.start_link(__MODULE__, [channel, config], name: name)
  end

  alias Otis.Pipeline.{Playlist, Hub, Broadcaster}

  def init([channel, config]) do
    Logger.info "#{__MODULE__} starting... #{ channel.id }"
    {:ok, playlist} = Playlist.start_link(channel.id)
    {:ok, hub} = Hub.start_link(playlist, config)
    {:ok, clock} = Otis.Pipeline.Config.start_clock(config)
    {:ok, broadcaster} = Broadcaster.start_link(channel.id, self(), hub, clock, config)
    {:ok, %S{
        id: channel.id,
        playlist: playlist,
        broadcaster: broadcaster,
        volume: Map.get(channel, :volume, 1.0)
      }
    }
  end

  def handle_call(:id, _from, %S{id: id} = state) do
    {:reply, {:ok, id}, state}
  end

  def handle_call({:play, false}, _from, state) do
    state = state |> set_state(:pause)
    {:reply, {:ok, state.state}, state}
  end
  def handle_call({:play, true}, _from, state) do
    state = state |> set_state(:play)
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:play_pause, _from, state) do
    state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:get_state, _from, %S{state: status} = state) do
    {:reply, {:ok, status}, state}
  end

  def handle_call(:get_playlist, _from, %S{playlist: playlist} = state) do
    {:reply, {:ok, playlist}, state}
  end

  def handle_call(:active_rendition, _from, %S{playlist: playlist} = state) do
    {:reply, Playlist.active_rendition(playlist), state}
  end

  def handle_call(:volume, _from, %S{volume: volume} = state) do
    {:reply, {:ok, volume}, state}
  end
  def handle_call({:volume, volume}, _from, state) do
    volume = Otis.sanitize_volume(volume)
    Otis.Receivers.Channels.volume_multiplier(state.id, volume)
    event!(state, :volume, [volume])
    {:reply, {:ok, volume}, %S{state | volume: volume}}
  end

  def handle_call({:append_sources, sources}, _from, state) do
    Playlist.append(state.playlist, sources)
    {:reply, :ok, state}
  end

  def handle_call({:remove_rendition, rendition_id}, _from, state) do
    Playlist.remove(state.playlist, rendition_id)
    {:reply, :ok, state}
  end

  def handle_call(:playing, _from, %S{state: status} = state) do
    {:reply, status == :play, state}
  end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, id}, state) do
    Broadcaster.skip(state.broadcaster, id)
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    Playlist.clear(state.playlist)
    {:noreply, state}
  end

  # Don't need to do anything here as the start has been initiated by us
  def handle_info(:broadcaster_start, state) do
    {:noreply, state}
  end
  # Stop events come when the audio has actually finished as well as when we
  # send a stop event
  def handle_info(:broadcaster_stop, state) do
    state = state |> set_state(:pause)
    {:noreply, state}
  end

  defp event!(state, name, params) do
    Strobe.Events.notify(:channel, name, [state.id | params])
  end

  defp toggle_state(%S{state: :play} = state) do
    set_state(state, :pause)
  end

  defp toggle_state(%S{state: :pause} = state) do
    set_state(state, :play)
  end

  defp set_state(%S{state: status} = state, status) do
    state
  end
  defp set_state(channel, state) do
    %S{ channel | state: state } |> change_state
  end

  defp change_state(%S{state: :play} = state) do
    Broadcaster.start(state.broadcaster)
    event!(state, :play_pause, [:play])
    state
  end
  defp change_state(%S{state: :pause} = state) do
    Broadcaster.pause(state.broadcaster)
    event!(state, :play_pause, [:pause])
    state
  end
end