defmodule ForwardingHandler do
  use GenStage
  use Strobe.Events.Handler, filter_complete: false

  def attach do
    {:ok, _pid} = start_link(self())
    :ok
  end

  def start_link(parent) do
    GenStage.start_link(__MODULE__, parent)
  end

  def init(parent) do
    {:consumer, parent, subscribe_to: Strobe.Events.producer}
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end
end

defmodule FilteredForwardingHandler do
  use GenStage
  use Strobe.Events.Handler

  def attach(selector) do
    {:ok, _pid} = start_link(self(), selector)
    :ok
  end

  def start_link(parent, selector) do
    GenStage.start_link(__MODULE__, {parent, selector})
  end

  def init({parent, selector}) do
    {:consumer, parent, subscribe_to: Strobe.Events.producer(selector)}
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end
end

ExUnit.start()
