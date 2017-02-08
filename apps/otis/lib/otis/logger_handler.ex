defmodule Otis.LoggerHandler do
  use     GenEvent
  require Logger

  @log_progress_every 100

  def init(id) do
    {:ok, %{id: id, progress_count: 0}}
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

  for evt <- [:library_request, :library_response, :add_library, :controller_join] do
    def handle_event({unquote(evt), _request}, state) do
      {:ok, state}
    end
  end

  def handle_event(event, state) do
    log_event(event, state)
    {:ok, state}
  end

  def log_event(event, _state) do
    Logger.info "EVENT: #{ inspect event }"
  end
end
