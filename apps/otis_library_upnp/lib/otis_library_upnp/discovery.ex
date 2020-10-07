defmodule Otis.Library.UPNP.Discovery do
  use GenServer

  require Logger
  alias Otis.Library.UPNP.Server

  @name Otis.Library.UPNP.Discovery

  defmodule S do
    defstruct devices: %{}
  end

  def all do
    GenServer.call(@name, :list)
  end

  def all! do
    {:ok, devices} = GenServer.call(@name, :list)
    devices
  end

  def lookup!(uuid) do
    {:ok, device} = GenServer.call(@name, {:lookup, uuid})
    device
  end

  def lookup(uuid) do
    GenServer.call(@name, {:lookup, uuid})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_opts) do
    Kernel.send(self(), :discover)
    {:ok, %S{}}
  end

  def handle_call(:list, _from, %S{devices: devices} = state) do
    {:reply, {:ok, Map.values(devices)}, state}
  end

  def handle_call({:lookup, uuid}, _from, %S{devices: devices} = state) do
    device = Map.fetch(devices, uuid)
    {:reply, device, state}
  end

  def handle_info(:discover, state) do
    state = discover() |> update_devices(state)
    Process.send_after(self(), :discover, 5_000)
    {:noreply, state}
  end

  defp discover do
    Nerves.SSDPClient.discover(target: "urn:schemas-upnp-org:device:MediaServer:1")
  end

  defp update_devices(results, %S{devices: devices} = state) do
    updated_devices =
      Enum.reduce(results, %{}, fn {uuid, server}, d ->
        device = Map.get(devices, uuid) || new_server(uuid, server)
        Map.put(d, uuid, device)
      end)

    %S{state | devices: updated_devices}
  end

  defp new_server(uuid, %{location: location}) do
    response = http(:get, location)
    spec = response.body |> Server.parse(uuid, location)

    Logger.info(
      "New UPnP server #{uuid} #{spec.name} [#{spec.location}] #{inspect(spec.directory)}"
    )

    spec
  end

  def http(:get, location) do
    HTTPoison.get!(location, [], [])
  end
end
