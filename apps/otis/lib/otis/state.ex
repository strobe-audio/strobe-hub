defmodule Otis.State do
  require Logger

  @doc "Returns the current state from the db"
  def current do
    %{ zones: zones(), receivers: receivers() }
  end

  defp zones do
    # TODO:
    # - status (playing/stopped)
    # - playlist
    # - current song
    Enum.map Otis.State.Zone.all, &zone_status/1
  end

  def receivers do
    # TODO: find live state
    Enum.map Otis.State.Receiver.all, &receiver_status/1
  end

  def zone_status(zone) do
    zone
  end

  def receiver_status(receiver) do
    receiver
  end
end
