defmodule Otis.LoggerHandler do
  use     GenStage
  require Logger

  @log_progress_every 100
  @silent_events [
    :add_library,
    :channel_play_pause,
    :controller_connect,
    :controller_join,
    :library_request,
    :library_response,
    :receiver_muted,
    :receiver_volume_change,
  ]

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(id) do
    {:consumer, %{id: id, progress_count: 0}, subscribe_to: Otis.Events.producer}
  end

  def handle_events([], _from,state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  for evt <- @silent_events do
    def handle_event({unquote(evt), _request}, state) do
      {:ok, state}
    end
  end

  def handle_event({:rendition_progress, [_channel_id, _rendition_id, _position, :infinity]}, state) do
    {:ok, state}
  end
  # Rate limit the source progress events to 1 out of @log_progress_every (or roughly every 10s)
  def handle_event({:rendition_progress, _args} = event, %{progress_count: 0} = state) do
    log_event(event, state)
    {:ok, %{state | progress_count: @log_progress_every}}
  end
  def handle_event({:rendition_progress, _args}, state) do
    {:ok, %{state | progress_count: state.progress_count - 1}}
  end

  def handle_event(event, state) do
    log_event(event, state)
    {:ok, state}
  end

  def log_event(event, _state) do
    Logger.debug "EVENT: #{ inspect event }"
  end
end
