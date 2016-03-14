defmodule Otis.LoggerHandler do
  use     GenEvent
  require Logger

  def init(id) do
    {:ok, %{id: id, progress_count: 0}}
  end

  # Rate limit the source progress events to 1 out of 10 (or roughly every 1s)
  def handle_event({:source_progress, _zone_id, _source_id, _position, _duration} = event, %{progress_count: 0} = state) do
    log_event(event, state)
    {:ok, %{state | progress_count: 10}}
  end
  def handle_event({:source_progress, _zone_id, _source_id, _position, _duration}, state) do
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
