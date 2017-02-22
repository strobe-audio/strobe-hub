defmodule Otis.DNSSD do
  use     GenServer
  require Logger

  @name Otis.DNSSD

  def start_link(pipeline_config) do
    GenServer.start_link(__MODULE__, pipeline_config, name: @name)
  end

  def init(pipeline_config) do
    state = %{ref: nil, pipeline_config: pipeline_config}
    case Application.ensure_all_started(:dnssd, :temporary) do
      {:ok, [_app]} ->
        Process.flag(:trap_exit, true)
        Logger.info "DNSSD: Registering #{inspect service_name(state)} on port #{service_port(state)} #{ inspect service_texts(state) }"
        {:ok, ref} = register_service(state)
        {:ok, %{state| ref: ref }}
      {:error, {_app, reason}} ->
        Logger.warn "DNSSD: Unable to start :dnssd application: #{inspect reason}"
        {:ok, state}
    end
  end

  def handle_info({:dnssd, _ref, _msg}, state) do
    # IO.inspect [__MODULE__, msg]
    {:noreply, state}
  end

  defp register_service(state) do
    :dnssd.register(service_name(state), service_port(state), service_texts(state))
  end

  def terminate(_reason, %{ref: nil}) do
    :ok
  end
  def terminate(_reason, %{ref: ref}) do
    :dnssd.stop(ref)
    :ok
  end

  defp service_name(_state) do
    "_peep-broadcaster._tcp"
  end

  defp service_port(_state) do
    config(Otis.SNTP)[:port]
  end

  defp service_texts(state) do
    receivers = config(Otis.Receivers)
    [ {:data_port, to_string(receivers[:data_port])},
      {:ctrl_port, to_string(receivers[:ctrl_port])},
      {:sntp_port, to_string(service_port(state))},
      {:stream_interval, to_string(state.pipeline_config.packet_duration_ms * 1000)},
      {:packet_size, to_string(state.pipeline_config.packet_size)},
    ]
  end

  defp config(mod) do
    Application.get_env(:otis, mod)
  end
end
