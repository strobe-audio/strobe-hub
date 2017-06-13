defmodule Strobe.Server.Startup do
  use GenStage

  defmodule S do
    @moduledoc false

    defstruct [
      run: %{ mount: false, avahi: false, dbus: false, ntpd: false }
    ]
  end

  @name __MODULE__

  def start_link do
    GenStage.start_link(__MODULE__, [], name: @name)
  end

  def init(_opts) do
    {:consumer, %S{}, subscribe_to: Strobe.Server.Events.producer}
  end

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:running, sys}, state) do
    state = running(sys, state) |> IO.inspect
    state |> ready? |> launch
    {:ok, state}
  end

  def handle_event(evt, state) do
    IO.inspect [__MODULE__, :event, evt, state]
    {:ok, state}
  end

  defp running([:mount, _device, _mount_point], %S{run: run} = state) do
    %S{ state | run: %{ run | mount: true } }
  end
  defp running([:dbus], %S{run: run} = state) do
    %S{ state | run: %{ run | dbus: true } }
  end
  defp running([:avahi], %S{run: run} = state) do
    %S{ state | run: %{ run | avahi: true } }
  end
  defp running([:ntpd], %S{run: run} = state) do
    %S{ state | run: %{ run | ntpd: true } }
  end

  defp ready?(state) do
    offline(state) == []
  end

  defp offline(%S{run: run} = state) do
    run
    |> Enum.filter(fn({_, s}) -> !s end)
    |> Enum.map(fn({k, _}) -> k end)
    |> IO.inspect
  end

  defp launch(false) do
    nil
  end

  defp launch(true) do
    IO.inspect [__MODULE__, :launch]
    Application.ensure_all_started(:elvis, :permanent)
  end
end
