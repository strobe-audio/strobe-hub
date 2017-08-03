defmodule Otis.SSDP do
  use     GenServer
  alias   Nerves.SSDPServer
  require Logger

  @service_uuid "ba31231a-5aee-11e6-8407-002500f418fc"

  def start_link(pipeline_config) do
    GenServer.start_link(__MODULE__, pipeline_config, name: __MODULE__)
  end

  def init(pipeline_config) do
    send(self(), :start)
    {:ok, pipeline_config}
  end

  def handle_info(:start, pipeline_config) do
    Logger.info "Starting SSDP server #{service_name(pipeline_config)}"
    case register_service(pipeline_config) do
      {:ok, _pid} ->
        Logger.info "Started SSDP server #{service_name(pipeline_config)}"
      other ->
        Logger.warn "Failed to start SSDP service #{service_name(pipeline_config)}: #{inspect other}"
        Process.send_after(self(), :start, 1_000)
    end
    {:noreply, pipeline_config}
  end

  defp register_service(pipeline_config) do
    SSDPServer.publish(service_name(pipeline_config), service_type(pipeline_config), service_texts(pipeline_config))
  end

  defp service_name(_pipeline_config) do
    "uuid:#{@service_uuid}::urn:com.peepaudio:broadcaster"
  end

  defp service_type(_pipeline_config) do
    "urn:com.peepaudio:broadcaster"
  end

  defp service_texts(pipeline_config) do
    receivers = config(Otis.Receivers)
    [{:data_port, to_string(receivers[:data_port])},
     {:port, service_port()},
     {:ctrl_port, to_string(receivers[:ctrl_port])},
     {:stream_interval, to_string(pipeline_config.packet_duration_ms * 1000)},
     {:packet_size, to_string(pipeline_config.packet_size)},
    ]
  end

  defp service_port do
    config(Otis.SNTP)[:port]
  end

  defp config(mod) do
    Application.get_env(:otis, mod)
  end
end
