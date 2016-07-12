defmodule HLS.DataStream do
  @moduledoc """
  Represents an actual data stream at a particular data rate
  """

  require Logger
  use   GenServer
  alias HLS.Stream

  defstruct [
    :stream,
    :url,
    :bandwidth,
  ]

  defmodule S do
    defstruct [
      stream: nil,
      url: nil,
      playlist: nil,
      # urls: [],
      waiting: nil,
      media: [],
      data: [],
      seq: 0,
      opts: [],
      reloading: false,
    ]
  end

  def open!(%Stream{} = stream, opts) do
    {:ok, pid} = HLS.DataStream.Supervisor.start(stream, opts)
    pid
  end

  def read!(pid) do
    {:ok, data} = GenServer.call(pid, :read)
    {[data], pid}
  end

  def close!(pid) do
    :ok = HLS.DataStream.Supervisor.stop(pid)
  end

  def start_link(%Stream{} = stream, opts) do
    GenServer.start_link(__MODULE__, [stream, opts])
  end

  def init([stream, opts]) do
    {:ok, %S{stream: stream, opts: opts}}
  end

  def handle_call(:read, from, state) do
    state = %S{state | waiting: from} |> read |> reload
    {:noreply, state}
  end

  def handle_cast({:data, {:data, id}, data}, state) do
    data = Enum.map(state.data, fn({data_id, _} = e) ->
      if data_id == id do
        {data_id, data}
      else
        e
      end
    end)
    state = %S{ state | data: data } |> read |> reload
    {:noreply, state}
  end

  def handle_cast({:data, {:playlist, _id}, data}, state) do
    playlist = M3.Parser.parse!(data, state.url)
    {:noreply, set_playlist(playlist, %S{state | reloading: false})}
  end

  defp set_playlist(%M3.Playlist.Live{media_sequence_number: msn} = playlist, state) do
    if msn == state.playlist.media_sequence_number do
      state |> reload
    else
      %S{ state | playlist: playlist, media: playlist.media } |> read
    end
  end
  defp set_playlist(_playlist, state) do
    state |> reload
  end

  defp reply({:ok, _data, %S{waiting: nil} = state}) do
    state
  end
  defp reply({:ok, data, %S{waiting: from} = state}) do
    GenServer.reply(from, {:ok, data})
    %S{ state | waiting: nil }
  end

  # defp read(%S{url: nil} = state, from) do
  # end
  defp read(%S{url: nil} = state) do
    playlist = Stream.resolve(state.stream, state.opts)
    read(%S{state | playlist: playlist, url: to_string(playlist.uri), media: playlist.media})
  end
  defp read(%S{media: [m | media]} = state) do
    state = %{state | media: media} |> retrieve(m)
    read(state)
  end
  defp read(%S{waiting: nil} = state) do
    state
  end
  defp read(%S{data: [{_id, packet} | data]} = state)
  when not is_nil(packet) do
    reply {:ok, packet, %S{state | data: data}}
  end
  defp read(state) do
    state
  end

  defp reload(%S{media: [], reloading: false} = state) do
    retrieve_playlist(state)
  end
  defp reload(state) do
    state
  end

  def retrieve(state, media) do
    worker = :poolboy.checkout(HLS.ReaderPool)
    {state, id} = request_id(state)
    HLS.Reader.Worker.read(worker, state.stream.reader, media.url, self(), {:data, id})
    %S{ state | data: state.data ++ [{id, nil}] }
  end

  def retrieve_playlist(state) do
    worker = :poolboy.checkout(HLS.ReaderPool)
    {state, id} = request_id(state)
    HLS.Reader.Worker.read(worker, state.stream.reader, state.url, self(), {:playlist, id})
    %S{state | reloading: true}
  end

  def request_id(%S{seq: seq} = state) do
    {%S{state | seq: seq + 1}, seq}
  end
end
