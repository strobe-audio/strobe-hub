defmodule Otis.Receivers.Protocol do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use     GenServer
      require Logger

      defmodule S do
        defstruct [:socket, :transport, :id, :supervisor, :settings]
      end

      def start_link(ref, socket, transport, opts) do
        :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
      end

      def init(ref, socket, transport, opts \\ []) do
        :ok = :proc_lib.init_ack({:ok, self})
        :ok = :ranch.accept_ack(ref)
        :ok = transport.setopts(socket, [mode: :binary, packet: 4, active: :once])
        state = %S{
          socket: socket,
          transport: transport,
          supervisor: opts[:supervisor],
          settings: initial_settings(),
        }
        state = monitor_connection(state)
        :gen_server.enter_loop(__MODULE__, [], state)
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
        GenServer.cast(state.supervisor, {:disconnect, unquote(opts[:type]), id})
        {:stop, :normal, state}
      end

      def handle_info({:tcp_error, _, reason}, %S{id: nil} = state) do
        {:stop, reason, state}
      end
      def handle_info({:tcp_error, _, reason}, %S{id: id} = state) do
        GenServer.cast(state.supervisor, {:disconnect, unquote(opts[:type]), id})
        {:stop, reason, state}
      end

      def process_message({_id, %{"pong" => _pong}}, state) do
        state
      end
      def process_message({id, params}, state) do
        Logger.info "Receiver connection #{unquote(opts[:type])} #{id} => #{ inspect params }"
        GenServer.cast(state.supervisor, {:connect, unquote(opts[:type]), id, {self, state.socket}, params})
        %S{ state | id: id }
      end
      def process_message(_msg, state) do
        state
      end

      def decode_message(data, state) do
        data |> Poison.decode! |> Map.pop("id")
      end

      def send_data(data, state) do
        state.transport.send(state.socket, data)
      end
    end
  end
end
