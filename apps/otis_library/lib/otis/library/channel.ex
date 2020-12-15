defmodule Otis.Library.Channel do
  @moduledoc """
  Encapsulate the action of adding sources to an Channel so that communication
  with live channels can be avoided in tests.

  All `play` methods return `nil` which is interpreted by the library system
  as "no response".
  """

  require Logger

  def play(nil, _channel_id) do
    nil
  end

  def play(sources, channel_id) when is_list(sources) do
    play_sources(sources, channel_id)
  end

  def play(track, channel_id) do
    play([track], channel_id)
  end

  defp play_sources(sources, channel_id) do
    Strobe.Events.notify(:library, :play, [channel_id, sources])
    nil
  end
end
