defmodule Peel.Webdav.Modifications do
  @moduledoc """
  Acts as en event source for library file modifications via webdav.
  """

  use GenStage

  def start_link(opts) do GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def notify(event) do
    GenServer.cast(__MODULE__, {:modification, event})
  end

  def complete(event) do
    GenServer.cast(__MODULE__, {:complete, event})
  end

  def init(_opts) do
    {:producer, %{}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  # Send all events immediately -- the webdav handler does most of the cleaning
  # up for us
  def handle_cast(evt, state) do
    {:noreply, [evt], state}
  end
end
