defmodule Otis.LoggerHandler do
  use GenStage
  use Strobe.Events.Handler
  require Logger

  @log_progress_every 100
  @silent_events [
    {:library, :add},
    {:channel, :play_pause},
    {:controller, :connect},
    {:controller, :join},
    {:library, :request},
    {:library, :response},
    {:receiver, :mute},
    {:receiver, :volume}
  ]

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(id) do
    {:consumer, %{id: id, progress_count: 0}, subscribe_to: Strobe.Events.producer()}
  end

  for {category, event} <- @silent_events do
    def handle_event({unquote(category), unquote(event), _args}, state) do
      {:ok, state}
    end
  end

  def handle_event(
        {:rendition, :progress, [_channel_id, _rendition_id, _position, :infinity]},
        state
      ) do
    {:ok, state}
  end

  # Rate limit the source progress events to 1 out of @log_progress_every (or roughly every 10s)
  def handle_event({:rendition, :progress, _args} = event, %{progress_count: 0} = state) do
    log_event(event, state)
    {:ok, %{state | progress_count: @log_progress_every}}
  end

  def handle_event({:rendition, :progress, _args}, state) do
    {:ok, %{state | progress_count: state.progress_count - 1}}
  end

  def handle_event(event, state) do
    log_event(event, state)
    {:ok, state}
  end

  def log_event(event, _state) do
    Logger.debug("EVENT: #{inspect(event)}")
  end
end
