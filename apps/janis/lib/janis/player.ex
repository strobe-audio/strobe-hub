defmodule Janis.Player do
  use GenServer
  require Logger

  @player_name Janis.Player

  def player_impl do
    Enum.find [Janis.Player.Jack, Janis.Player.Sox], fn(m) -> m.binary |> File.exists? end
  end

  def start_link do
    player_module = player_impl
    Logger.info "Starting player #{player_module}"
    GenServer.start_link(player_module, :ok, name: @player_name)
  end

  def play(data, timestamp) do
    play(@player_name, data, timestamp)
  end

  def play(pid, data, timestamp) do
    GenServer.cast(pid, {:play, data, timestamp})
  end

#   defmodule Packet do
#     @jitter 5
#     def start_link(data, timestamp, deadline, proc) do
# state = {data, timestamp, deadline, proc}
#       microseconds = timestamp - Janis.microseconds
#       adj = microseconds - @jitter
#       case adj > 3000 do
#         true ->
#           :timer.sleep(milliseconds(adj) - 1)
#           :erlang.send_after(milliseconds(adj) - 1, self, :immediate)
#           {:ok, state}
#         false ->
#           immediate()
#       end
#       {finish, loops} = busywait_until(timestamp, 1)
#       {:ok, state}
#     end
#
#     def immediate({data, timestamp, deadline, proc} = state) do
#     end
#   end

  defmacro __using__(_) do
    quote location: :keep do
      require Logger

      defmodule S do
        defstruct process: nil
      end

      @doc false
      def init(:ok) do
        {:ok, start_player}
      end

      @doc false
      defp start_player do
        opts = [in: :receive, out: nil, err: {:send, self}]
        proc = Porcelain.spawn(binary, params, opts)
        GenServer.cast(self, :startup)
        %S{process: proc}
      end

      @doc false
      def handle_cast(:startup, %S{process: proc} = state) do
        Logger.debug "Startup chime..."
        Porcelain.Process.send_input(proc, <<0, 0, 0, 0>>)
        {:noreply, state}
      end

      @doc false
      def handle_cast({:play, data, timestamp, deadline}, state) do
        # Logger.debug "play #{inspect(data)}"
        _play(data, timestamp, deadline, state)
      end

      def handle_info(msg, state) do
        IO.inspect [:info, msg]
        {:noreply, state}
      end

      def terminate(reason, state) do
        # Logger.info "Terminated. Reason: #{reason}"
        IO.inspect [:terminate, reason]
        :ok
      end

      # sending an empty message terminates the player process
      @doc false
      defp _play(<<>>, _, _, state) do
        {:noreply, state}
      end

      # sending an empty message terminates the player process
      @doc false
      defp _play(nil, _, _, state) do
        {:noreply, state}
      end

      @doc false
      defp _play(data, timestamp, deadline, %S{process: proc} = state) do
        now = Janis.microseconds
        if (timestamp > now) && (deadline > now) do
          wait = timestamp - now
          Janis.Microsleep.microsleep(wait)
          now = Janis.microseconds
          # Logger.debug("#{timestamp - now}")
          if (deadline > now) do
            Porcelain.Process.send_input(proc, data)
            # IO.binwrite(:stdio, data)
          else
            Logger.warn "Dropping delayed packet. Time: #{now}; Timestamp: #{timestamp}; Diff: #{now - timestamp}µs"
          end
        else
          Logger.warn "Dropping  late   packet. Time: #{now}; Timestamp: #{timestamp}; Diff: #{now - timestamp}µs"
        end
        {:noreply, state}
      end

      @doc false
      def shell_cmd do
        Enum.join [ binary | params ], " "
      end

      @doc false
      def params, do: []

      @doc false
      def binary, do: ""

      defoverridable [binary: 0, params: 0]
    end
  end
end
