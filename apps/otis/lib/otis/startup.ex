defmodule Otis.Startup do
  use     GenServer
  require Logger

  def start_link(state \\ Otis.State, channels_supervisor \\ Otis.Channels)
  def start_link(state, channels_supervisor) do
    GenServer.start_link(__MODULE__, [state, channels_supervisor], [])
  end

  def init([state, channels_supervisor]) do
    :ok = state |> start_channels(channels_supervisor)
    :ok = state |> restore_source_lists(channels_supervisor)
    Otis.State.Events.add_handler(Otis.LoggerHandler, :events)
    Otis.State.Events.notify({:otis_started, []})
    :ignore
  end

  def start_channels(_state, channels_supervisor) do
    ignoring_errors_in_tests fn ->
      channels = Otis.State.Channel.all
      channels |> guarantee_channel |> start_channel(channels_supervisor)
    end
  end

  defp guarantee_channel([]) do
    [Otis.State.Channel.create_default!]
  end
  defp guarantee_channel(channels) do
    channels
  end

  defp start_channel([channel | rest], channels_supervisor) do
    Logger.info "===> Starting channel #{ channel.id } #{ inspect channel.name }"
    Otis.Channels.start(channels_supervisor, channel.id, channel)
    start_channel(rest, channels_supervisor)
  end

  defp start_channel([], _channels_supervisor) do
    :ok
  end

  def restore_source_lists(_state, channels_supervisor) do
    ignoring_errors_in_tests fn ->
      {:ok, channels} = Otis.Channels.list(channels_supervisor)
      channels |> restore_source_list
    end
  end
  defp restore_source_list([]) do
    :ok
  end
  defp restore_source_list([channel | channels]) do
    {:ok, channel_id} = Otis.Channel.id(channel)
    {:ok, source_list} = Otis.Channel.source_list(channel)
    sources = Otis.State.Source.restore(channel_id)
    Otis.SourceList.replace(source_list, sources)
    restore_source_list(channels)
  end

  # We're not guaranteed to have a valid db schema when running in test mode
  # so just ignore those errors here (assuming that anything less transitory
  # will be caught by the tests themselves)
  defp ignoring_errors_in_tests(action) do
    try do
      action.()
    rescue
      Sqlite.Ecto.Error ->
        case Mix.env do
          :test -> nil
          _ ->
            Logger.error "Invalid db schema"
        end
        :ok
    end
  end
end
