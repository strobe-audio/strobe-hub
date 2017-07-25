defmodule Otis.Library.Channel do
  @moduledoc """
  Encapsulate the action of adding sources to an Channel so that communication
  with live channels can be avoided in tests.
  """

  def play(nil, _channel_id) do
    :ok
  end
  def play(sources, channel_id) when is_list(sources) do
    play_sources(sources, channel_id)
  end
  def play(track, channel_id) do
    play([track], channel_id)
  end

  if Mix.env == :test do
    defp play_sources(sources, channel_id) do
      Strobe.Events.notify(:library, :play, [channel_id, sources])
    end
  else
    defp play_sources(sources, channel_id) do
      with {:ok, channel} <- Otis.Channels.find(channel_id) do
        Otis.Channel.append(channel, sources)
      else
        err -> err
      end
    end
  end
end
