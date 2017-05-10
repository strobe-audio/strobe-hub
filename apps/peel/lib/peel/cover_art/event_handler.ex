defmodule Peel.CoverArt.EventHandler do
  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  @timeout 5_000

  def init(_opts) do
    {:consumer, %{timer: nil},
      subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
  end

  defp selector({:complete, {:create, _args}}), do: true
  defp selector(_evt), do: false

  def handle_events(events, _from, state) do
    {:noreply, [], kick(state)}
  end

  def handle_info(:activate, state) do
    Peel.CoverArt.Importer.start()
    {:noreply, [], reset(state)}
  end

  defp kick(state) do
    state |> reset |> restart
  end

  defp reset(%{timer: nil} = state) do
    state
  end
  defp reset(%{timer: timer} = state) do
    Process.cancel_timer(timer)
    %{ state | timer: nil }
  end

  defp restart(state) do
    %{ state | timer: Process.send_after(self(), :activate, @timeout) }
  end
end
