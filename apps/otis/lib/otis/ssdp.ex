defmodule Otis.SSDP do
  use   GenServer
  alias Nerves.SSDPServer

  @service_uuid "ba31231a-5aee-11e6-8407-002500f418fc"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    IO.inspect __MODULE__
    register_service()
    {:ok, %{}}
  end

  defp register_service do
    SSDPServer.publish(service_name(), service_type(), service_texts())
  end

  defp service_name do
    "uuid:#{@service_uuid}::urn:com.peepaudio:broadcaster"
  end

  defp service_type do
    "urn:com.peepaudio:broadcaster"
  end

  defp service_texts do
    receivers = config(Otis.Receivers)
    [ {:data_port, to_string(receivers[:data_port])},
      {:port, service_port()},
      {:ctrl_port, to_string(receivers[:ctrl_port])},
      {:stream_interval, to_string(Otis.stream_interval_us)},
      {:packet_size, to_string(Otis.stream_bytes_per_step)},
    ]
    |> IO.inspect
  end

  defp service_port do
    config(Otis.SNTP)[:port]
  end

  defp config(mod) do
    Application.get_env :otis, mod
  end
end
