defmodule Otis.DNSSD do
  use     GenServer
  require Logger

  @name Otis.DNSSD

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    Logger.info "Registering #{inspect service_name} on port #{service_port} #{ inspect service_texts }"
    {:ok, ref} = register_service
    {:ok, %{ref: ref}}
  end

  defp register_service do
    :dnssd.register(service_name, service_port, service_texts)
  end

  def terminate(_reason, %{ref: ref}) do
    :dnssd.stop(ref)
    :ok
  end

  defp service_name do
    "_peep-broadcaster._tcp"
  end

  defp service_port do
    config(Otis.SNTP)[:port]
  end

  defp service_texts do
    receivers = config(Otis.Receivers)
    [ {:data_port, to_string(receivers[:data_port])},
      {:ctrl_port, to_string(receivers[:ctrl_port])},
      {:stream_interval, to_string(Otis.stream_interval_us)},
      {:packet_size, to_string(Otis.stream_bytes_per_step)},
    ]
  end

  defp config(mod) do
    Application.get_env :otis, mod
  end
end
