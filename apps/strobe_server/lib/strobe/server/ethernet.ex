defmodule Strobe.Server.Ethernet do
  use GenServer
  require Logger

  @name __MODULE__

  def start_link(dev \\ "eth0") do
    GenServer.start_link(__MODULE__, dev, name: @name)
  end

  def init(dev) do
    send(self(), :start)
    Registry.register(Nerves.NetworkInterface, dev, [])
    {:ok, dev}
  end

  case Code.ensure_compiled(Nerves.Networking) do
    {:module, _module} ->
      def handle_info(:start, dev) do
        {:ok, _pid} = Nerves.Networking.setup(String.to_atom(dev), mode: "dhcp")
        {:noreply, dev}
      end

    {:error, _} ->
      def handle_info(:start, dev) do
        {:noreply, dev}
      end
  end

  def handle_info(
        {Nerves.NetworkInterface, :ifchanged, %{ifname: dev, operstate: :up} = event},
        dev
      ) do
    Logger.debug("nerves_network_interface:ifchanged #{dev} #{inspect(event)}")
    # device_changed(dev, ethernet_carrier?(), event)
    {:noreply, dev}
  end

  def handle_info(event, dev) do
    Logger.debug("nerves_network_interface:handle_info #{dev} #{inspect(event)}")
    {:noreply, dev}
  end
end
