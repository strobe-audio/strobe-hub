defmodule Otis.ReceiverSocket do
  defmodule Protocol do
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
          :ok = transport.setopts(socket, [active: :once])
          state = %S{
            socket: socket,
            transport: transport,
            supervisor: opts[:supervisor],
            settings: initial_settings(),
          }
          :gen_server.enter_loop(__MODULE__, [], state)
        end

        def handle_info({:tcp, _socket, data}, state) do
          state.transport.setopts(state.socket, [active: :once])
          state = data |> decode_message(state) |> process_message(state)
          {:noreply, state}
        end

        def handle_info({:tcp_closed, _socket}, %S{id: nil} = state) do
          {:noreply, state}
        end
        def handle_info({:tcp_closed, _socket}, %S{id: id} = state) do
          GenServer.cast(state.supervisor, {:disconnect, unquote(opts[:type]), id, self})
          {:noreply, state}
        end

        def process_message({id, params}, state) do
          Logger.info "Receiver connection #{unquote(opts[:type])} #{id} => #{ inspect params }"
          GenServer.cast(state.supervisor, {:connect, unquote(opts[:type]), id, self, params})
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

  defmodule DataConnection do
    use Protocol, type: :data

    defp initial_settings, do: %{}
  end

  defmodule ControlConnection do
    use Protocol, type: :control

    def set_volume(connection, volume) do
      GenServer.cast(connection, {:set_volume, volume})
    end

    def set_volume(connection, volume, multiplier) do
      GenServer.cast(connection, {:set_volume, volume, multiplier})
    end

    def get_volume(connection) do
      GenServer.call(connection, :get_volume)
    end

    def set_volume_multiplier(connection, multiplier) do
      GenServer.cast(connection, {:set_volume_multiplier, multiplier})
    end

    def get_volume_multiplier(connection) do
      GenServer.call(connection, :get_volume_multiplier)
    end

    def handle_cast({:set_volume, volume}, state) do
      state = change_volume(state, [volume: volume])
      {:noreply, state}
    end

    def handle_cast({:set_volume, volume, multiplier}, state) do
      state = change_volume(state, [volume: volume, volume_multiplier: multiplier])
      {:noreply, state}
    end

    def handle_cast({:set_volume_multiplier, multiplier}, state) do
      state = change_volume(state, [volume_multiplier: multiplier])
      {:noreply, state}
    end

    def handle_call(:get_volume, _from, state) do
      {:reply, Map.fetch(state.settings, :volume), state}
    end

    def handle_call(:get_volume_multiplier, _from, state) do
      {:reply, Map.fetch(state.settings, :volume_multiplier), state}
    end

    defp initial_settings, do: %{volume: 1.0, volume_multiplier: 1.0}

    defp change_volume(state, values) do
      v1 = Map.take(state.settings, [:volume, :volume_multiplier])
      settings = Enum.into(values, state.settings)
      v2 = Map.take(settings, [:volume, :volume_multiplier])
      %S{state | settings: settings} |> monitor_volume(values, v1, v2)
    end

    defp monitor_volume(state, _values, volume, volume) do
      state
    end
    defp monitor_volume(state, values, initial_volume, final_volume) do
      volume = calculated_volume(final_volume)
      %{ volume: volume } |> Poison.encode! |> send_data(state)
      notify_volume(state, values)
    end

    defp notify_volume(%S{settings: settings} = state, values) do
      # Don't send an event when changing the multiplier as the multiplier is a
      # zone-level property and events for it are emitted there.
      if Keyword.has_key?(values, :volume) do
        Otis.State.Events.notify({:receiver_volume_change, state.id, settings.volume})
      end
      state
    end

    defp calculated_volume(%S{settings: settings} = _state) do
      calculated_volume(settings)
    end
    defp calculated_volume(%{volume: volume, volume_multiplier: multiplier}) do
      volume * multiplier
    end
  end

  use     GenServer
  require Logger
  alias   Otis.Receiver2, as: Receiver

  @name Otis.ReceiverSocket

  defmodule S do
    defstruct [receivers: %{}]
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def receivers do
    receivers(@name)
  end

  def receivers(pid) do
    GenServer.call(pid, :receivers)
  end

  def receiver(id) do
    receiver(@name, id)
  end

  def receiver(pid, id) do
    GenServer.call(pid, {:receiver, id})
  end

  defp config do
    Application.get_env :otis, __MODULE__
  end

  def data_port, do: config[:data_port]
  def ctrl_port, do: config[:ctrl_port]

  # At the receiver end:
  # {:ok, s} = Socket.TCP.connect "192.168.1.117", 5540, [mode: :active]
  # :gen_tcp.send s, "id:" <> Janis.receiver_id
  # :gen_tcp.close s
  def init([]) do
    {:ok, _data_pid} = start_listener(@name.DataListener, data_port, DataConnection)
    {:ok, _ctrl_pid} = start_listener(@name.ControlListener, ctrl_port, ControlConnection)
    {:ok, %S{}}
  end

  defp start_listener(name, port, protocol) do
    :ranch.start_listener(name, 10, :ranch_tcp, [port: port, packet: 4], protocol, [supervisor: @name])
  end

  def handle_cast({:connect, :data, id, pid, params}, %S{receivers: receivers} = state) do
    state = connect(:data, id, pid, params, Map.get(state.receivers, id), state)
    # IO.inspect [:connect, :data, state]
    {:noreply, state}
  end
  def handle_cast({:connect, :control, id, pid, params}, state) do
    state = connect(:control, id, pid, params, Map.get(state.receivers, id), state)
    # IO.inspect [:connect, :control, state]
    {:noreply, state}
  end
  def handle_cast({:disconnect, :data, id, pid}, state) do
    state = disconnect(:data, id, pid, Map.get(state.receivers, id), state)
    {:noreply, state}
  end
  def handle_cast({:disconnect, :control, id, pid}, state) do
    state = disconnect(:control, id, pid, Map.get(state.receivers, id), state)
    {:noreply, state}
  end

  def handle_call(:receivers, _from, %S{receivers: receivers} = state) do
    {:reply, Map.values(receivers), state}
  end

  def handle_call({:receiver, id}, _from, %S{receivers: receivers} = state) do
    {:reply, Map.fetch(receivers, id), state}
  end

  def connect(:control, id, socket, params, nil, state) do
    Receiver.new(id: id, ctrl_socket: socket, params: params) |> update_connect(id, state)
  end
  def connect(:control, id, socket, params, receiver, state) do
    Receiver.update(receiver, ctrl_socket: socket, params: params) |> update_connect(id, state)
  end

  def connect(:data, id, socket, params, nil, state) do
    Receiver.new(id: id, data_socket: socket, params: params) |> update_connect(id, state)
  end
  def connect(:data, id, socket, params, receiver, state) do
    Receiver.update(receiver, data_socket: socket, params: params) |> update_connect(id, state)
  end

  def disconnect(type, id, pid, nil, state) do
    Logger.warn "#{ inspect type } disconnect from unknown receiver #{ id }"
  end
  def disconnect(:data, id, pid, receiver, state) do
    Receiver.update(receiver, data_socket: nil) |> update_disconnect(id, state)
  end
  def disconnect(:control, id, pid, receiver, state) do
    Receiver.update(receiver, ctrl_socket: nil) |> update_disconnect(id, state)
  end

  def update_connect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_connect(receiver)
  end

  def update_disconnect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_disconnect(receiver)
  end

  def update_receiver(receiver, id, state) do
    %{ state | receivers: Map.put(state.receivers, id, receiver)}
  end

  def after_connect(state, receiver) do
    start_valid_receiver(state, receiver, Receiver.alive?(receiver))
  end

  def after_disconnect(state, receiver) do
    state
    |> disable_zombie_receiver(receiver, Receiver.zombie?(receiver))
    |> remove_dead_receiver(receiver, Receiver.dead?(receiver))
  end

  def start_valid_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_connected, receiver.id, receiver})
    state
  end
  def start_valid_receiver(state, receiver, false) do
    state
  end

  def disable_zombie_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_disconnected, receiver.id, receiver})
    state
  end
  def disable_zombie_receiver(state, receiver, false) do
    state
  end

  def remove_dead_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_offline, receiver.id, receiver})
    %{state | receivers: Map.delete(state.receivers, receiver.id)}
  end
  def remove_dead_receiver(state, receiver, false) do
    state
  end
end
