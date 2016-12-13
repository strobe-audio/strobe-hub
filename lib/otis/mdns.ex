defmodule Otis.Mdns do
  use   GenServer
  require Logger

  def start_link(pipeline_config) do
    GenServer.start_link(__MODULE__, pipeline_config, name: __MODULE__)
  end

  def init(pipeline_config) do
    Logger.info "Starting mDNS server"
    # MOve this into some nerves app
    # Mdns.Server.start()
    ptr = %Mdns.Server.Service{
      domain: service_name(),
      data: data(pipeline_config),
      ttl: 120,
      type: :srv,
    }# |> IO.inspect
    Mdns.Server.add_service(ptr)
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  defp service_name do
    "_peep-broadcaster._tcp"
  end

  defp service_port do
    config(Otis.SNTP)[:port]
  end

  defp data(pipeline_config) do
    Enum.map(service_texts(pipeline_config), fn({k, v}) ->
      "#{k}=#{v}"
    end)
  end

  defp service_texts(pipeline_config) do
    receivers = config(Otis.Receivers)
    [ {:data_port, to_string(receivers[:data_port])},
      {:ctrl_port, to_string(receivers[:ctrl_port])},
      {:stream_interval, to_string(pipeline_config.packet_duration_ms * 1000)},
      {:packet_size, to_string(pipeline_config.packet_size)},
    ]
  end

  defp config(mod) do
    Application.get_env(:otis, mod)
  end
end
