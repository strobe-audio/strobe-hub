defmodule Otis.Pipeline.Hub do
  @moduledoc """
  The interface between a broadcaster and a playlist: converts a playlist into
  a constant stream of %Packet{}s by creating sequential `Buffer`s from the
  playlist entries.
  """

  use GenServer

  alias Otis.Pipeline.Playlist
  alias Otis.Pipeline.Producer
  alias Otis.Pipeline.Streams

  defmodule S do
    @moduledoc false
    defstruct [
      :playlist,
      :config,
      :rendition,
      :stream,
    ]
  end

  def start_link(playlist, config) do
    GenServer.start_link(__MODULE__, [playlist, config])
  end

  def skip(hub, rendition_id) do
    GenServer.call(hub, {:skip, rendition_id})
  end

  def pause(hub) do
    Producer.pause(hub)
  end

  def init([playlist, config]) do
    {:ok, %S{playlist: playlist, config: config}}
  end

  def handle_call(:next, _from, state) do
    {reply, state} = next_packet(state)
    {:reply, reply, state}
  end

  def handle_call({:skip, rendition_id}, _from, state) do
    Playlist.skip(state.playlist, rendition_id)
    {:reply, :ok, shutdown(state)}
  end

  def handle_call(:pause, _from, state) do
    {reply, state} = pause_stream(state)
    {:reply, reply, state}
  end

  ## Next handing

  defp next_packet(%S{stream: nil} = state) do
    state |> load_pending_stream() |> load_packet()
  end
  defp next_packet(state) do
    load_packet({:ok, state})
  end

  # So we've come from receiving a :done state from our previous stream and
  # still haven't managed to load a stream, so tell our broadcaster we're done
  defp load_packet({:done, state}) do
    {:done, state}
  end
  defp load_packet({:ok, %S{stream: stream} = state}) do
    stream |> Producer.next() |> handle_data(state)
  end

  defp handle_data({:ok, data}, state) do
    {{:ok, data}, state}
  end
  defp handle_data({:done, data}, state) do
    {{:ok, data}, state}
  end
  defp handle_data(:done, state) do
    %S{state | stream: nil, rendition: nil} |> load_pending_stream() |> load_packet()
  end

  # The case when we've paused a live stream
  defp load_pending_stream(%S{stream: nil, rendition: rendition_id} = state)
  when not is_nil(rendition_id) do
    {:ok, stream} = start_stream(rendition_id, state)
    {:ok, %S{state| stream: stream}}
  end
  defp load_pending_stream(state) do
    case Playlist.next(state.playlist) do
      {:ok, rendition_id} ->
        {:ok, stream} = start_stream(rendition_id, state)
        {:ok, %S{ state | stream: stream, rendition: rendition_id }}
      :done ->
        {:done, state}
    end
  end

  defp start_stream(rendition_id, state) do
    Streams.start_stream(rendition_id, state.config)
  end

  ## Pause handling

  defp pause_stream(%S{stream: nil} = state) do
    {:ok, state}
  end
  defp pause_stream(%S{stream: stream} = state) do
    pause_stream(state, Producer.pause(stream))
  end
  defp pause_stream(state, :ok) do
    {:ok, state}
  end
  defp pause_stream(%S{stream: stream} = state, :stop) do
    shutdown_producer(stream)
    {:stop, %S{state | stream: nil}}
  end

  defp shutdown(state) do
    shutdown_producer(state.stream)
    %S{state | stream: nil, rendition: nil}
  end

  defp shutdown_producer(nil) do
  end
  defp shutdown_producer(stream) do
    Producer.stop(stream)
  end
end
