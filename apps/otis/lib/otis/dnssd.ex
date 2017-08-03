defmodule Otis.DNSSD do
  use     GenServer
  require Logger

  @name Otis.DNSSD

  def start_link(pipeline_config) do
    GenServer.start_link(__MODULE__, pipeline_config, name: @name)
  end

  def init(pipeline_config) do
    start_dnssd(%{ref: nil, pipeline_config: pipeline_config})
  end

  def handle_info({:dnssd, _ref, _msg}, state) do
    {:noreply, state}
  end

  if Code.ensure_compiled?(:dnssd) do
    defp start_dnssd(state) do
      case Application.ensure_all_started(:dnssd, :temporary) do
        {:ok, _} ->
          Process.flag(:trap_exit, true)
          {:ok, ref} = register_service(state)
          {:ok, %{state| ref: ref}}
        {:error, {_app, reason}} ->
          Logger.warn "DNSSD: Unable to start :dnssd application: #{inspect reason}"
          {:ok, state}
      end
    end

    defp register_service(state) do
      Logger.info "DNSSD: Registering #{inspect service_name(state)} on port #{service_port(state)} #{ inspect service_texts(state) }"
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
      [{:data_port, to_string(receivers[:data_port])},
       {:ctrl_port, to_string(receivers[:ctrl_port])},
       {:sntp_port, to_string(service_port(state))},
       {:stream_interval, to_string(state.pipeline_config.packet_duration_ms * 1000)},
       {:packet_size, to_string(state.pipeline_config.packet_size)},
      ]
    end

    defp config(mod) do
      Application.get_env(:otis, mod)
    end
  else
    defp start_dnssd(state) do
      {:ok, state}
    end

    def terminate(_reason, _state) do
      :ok
    end
  end

end
