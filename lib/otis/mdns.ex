defmodule Otis.Mdns do
  use   GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  # defp service_name do
  #   "_peep-broadcaster._tcp"
  # end
  #
  # defp service_port do
  #   config(Otis.SNTP)[:port]
  # end
  #
  # defp service_texts do
  #   receivers = config(Otis.Receivers)
  #   [ {:data_port, to_string(receivers[:data_port])},
  #     {:ctrl_port, to_string(receivers[:ctrl_port])},
  #     {:stream_interval, to_string(Otis.stream_interval_us)},
  #     {:packet_size, to_string(Otis.stream_bytes_per_step)},
  #   ]
  # end
  #
  # defp config(mod) do
  #   Application.get_env :otis, mod
  # end
end
