defmodule Otis.DNSSD do
  use     GenServer
  require Logger

  @name Otis.DNSSD

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    Logger.info "Registering #{inspect service_name} on port #{service_port}"
    {:ok, ref} = register_service
    {:ok, %{ref: ref}}
  end

  defp register_service do
    :dnssd.register(service_name, service_port, service_texts)
  end

  def terminate(reason, %{ref: ref} = state) do
    :dnssd.stop(ref)
    :ok
  end

  defp service_name do
    config[:name]
  end

  defp service_port do
    config[:port]
  end

  defp service_texts do
    [ {:socket_path, "/receive/websocket"} ]
  end

  defp config do
    Application.get_env :otis, Otis.DNSSD
  end
end
