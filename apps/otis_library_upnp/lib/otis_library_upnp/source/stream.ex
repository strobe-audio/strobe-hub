defmodule Otis.Library.UPNP.Source.Stream do
  use GenStage

  alias Otis.Library.UPNP.{Item}

  require Logger

  defmodule S do
    defstruct [:source, :headers, :response, :demand]
  end

  def start_link(source) do
    GenStage.start_link(__MODULE__, source)
  end

  def init(source) do
    url = Item.source_url(source)
    {:ok, response} = HTTPoison.get url, [], [stream_to: self(), async: :once]
    {:producer, stream_next(%S{source: source, response: response, demand: 0}, true)}
  end

  def handle_demand(_new_demand, %S{response: nil} = state) do
    {:stop, :normal, state}
  end
  def handle_demand(new_demand, %S{demand: demand} = state) do
    {:noreply, [], stream_next(%S{ state | demand: demand + new_demand })}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    {:noreply, [], stream_next(state, true)}
  end
  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    Logger.warn "Got status #{code} from #{inspect state.source}"
    {:stop, {:error, code}, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{}, state) do
    {:noreply, [], stream_next(state)}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, %S{demand: demand} = state) do
    {:noreply, [chunk], stream_next(%S{state | demand: max(0, demand - 1)})}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    GenStage.async_notify(self(), {:producer, :done})
    {:noreply, [], %S{state | demand: 0, response: nil}}
  end

  defp stream_next(state, always \\ false)
  defp stream_next(%S{demand: 0} = state, false) do
    state
  end
  defp stream_next(state, false) do
    stream_next(state, true)
  end
  defp stream_next(%S{response: response} = state, true) do
    {:ok, response} = HTTPoison.stream_next(response)
    %S{state | response: response}
  end
end
