defmodule Otis.Receivers.Protocol do
  @moduledoc false
  defmacro __using__(opts) do
    quote location: :keep do
      use     GenServer
      require Logger

      defmodule S do
        defstruct [:socket, :transport, :id, :supervisor, :settings, :monitor_timeout]
      end

      def start_link(ref, socket, transport, opts) do
        :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
      end

      def init(ref, socket, transport, opts \\ []) do
        pipeline_config = opts[:pipeline_config]
        :ok = :proc_lib.init_ack({:ok, self()})
        :ok = :ranch.accept_ack(ref)
        :ok = transport.setopts(socket, socket_opts(pipeline_config))
        state = %S{
          socket: socket,
          transport: transport,
          supervisor: opts[:supervisor],
          settings: initial_settings(),
        }
        state = state |> monitor_connection
        :gen_server.enter_loop(__MODULE__, [], state)
      end

      def handle_cast(:disconnect, state) do
        close_and_disconnect(state)
        {:stop, :normal, state}
      end

      def handle_info({:tcp, _socket, data}, state) do
        state.transport.setopts(state.socket, [active: :once])
        state = data |> decode_message(state) |> process_message(state)
        {:noreply, state}
      end

      def handle_info({:tcp_closed, _socket}, %S{id: nil} = state) do
        {:stop, :normal, state}
      end
      def handle_info({:tcp_closed, _socket}, %S{id: id} = state) do
        disconnect(state)
        {:stop, :normal, state}
      end

      def handle_info({:tcp_error, _, reason}, state) do
        close_and_disconnect(state)
        {:stop, reason, state}
      end

      def process_message({_id, %{"pong" => _pong}}, state) do
        receiver_alive(state)
      end
      def process_message({id, params}, state) do
        Logger.info "Receiver connection #{unquote(opts[:type])} #{id} => #{ inspect params }"
        GenServer.cast(state.supervisor, {:connect, unquote(opts[:type]), id, {self(), state.socket}, params})
        %S{ state | id: id }
      end
      def process_message(_msg, state) do
        state
      end

      def disconnect(%S{id: id} = state, reason \\ :normal) do
        GenServer.cast(state.supervisor, {:disconnect, unquote(opts[:type]), id, self(), reason})
      end

      def close_and_disconnect(%S{id: id} = state, reason \\ :normal) do
        state |> close |> disconnect(reason)
      end

      def decode_message(data, state) do
        data |> Poison.decode! |> Map.pop("id")
      end

      def send_command(data, state) do
        data |> Poison.encode! |> send_data(state)
      end

      def send_data(packets, state) do
        errors = packets
        |> List.wrap
        |> Enum.map(fn(data) -> state.transport.send(state.socket, data) end)
        |> return_errors()
      end

      def return_errors(errors) do
        errors
        |> Enum.filter(&is_error_response?/1)
        |> case do
          [error | _] -> error
          [] -> :ok
        end
      end

      defp is_error_response?({:error, _reason}), do: true
      defp is_error_response?(:ok), do: false

      defp close(state) do
        :ok = state.transport.close(state.socket)
        state
      end

      defp socket_opts(pipeline_config) do
        [ mode: :binary,
          packet: 4,
          active: :once,
          keepalive: true,
          nodelay: true,
          send_timeout: 2_000*pipeline_config.packet_duration_ms,
        ]
      end
    end
  end
end
