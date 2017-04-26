defmodule Otis.Library.Events do
  # Used by event consumers to subscribe to event producer if it's available
  def producer do
    Otis.Events |> GenServer.whereis |> List.wrap
  end
end
