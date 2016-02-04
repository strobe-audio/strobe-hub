# defmodule FakeMonitor do
#   @moduledoc """
#   Accepts all the messages that the real player status module does.
#   """
#
#   use GenServer
#
#
#   defmodule S do
#     # pretend to have these values
#     defstruct time_diff: 22222222, delay: 1000 # both in us
#   end
#
#   def start do
#     case GenServer.start_link(FakeMonitor, :ok, name: Janis.Monitor) do
#       {:ok, monitor} -> {:ok, monitor }
#       {:error, {:already_started, monitor}} -> {:ok, monitor }
#       _ -> raise "huh?"
#     end
#   end
#
#   def init( :ok ) do
#     {:ok, %S{}}
#   end
#
#   def handle_call({:sync, {originate_ts} = _packet}, _from, state) do
#     {:reply, {originate_ts, fake_time(originate_ts, state)}, state}
#   end
#
#   def fake_time(originate_ts, %S{time_diff: time_diff, delay: delay} = _state) do
#     originate_ts - (delay*0) + time_diff
#   end
# end

# {:ok, _monitor} = FakeMonitor.start

defmodule TestHandler do
  use GenEvent

  def init(_args) do
    {:ok, []}
  end

  def handle_event(event, messages) do
    {:ok, [event|messages]}
  end

  def handle_call(:messages, messages) do
    {:ok, Enum.reverse(messages), []}
  end
end

defmodule MessagingHandler do
  use GenEvent

  def init(parent) do
    {:ok, parent}
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end

  # Allows tests to wait for successful removal of the handler
  #
  #    on_exit fn ->
  #      Otis.State.Events.remove_handler(MessagingHandler, self)
  #      assert_receive :remove_messaging_handler, 200
  #    end

  def terminate(pid, parent)
  when is_pid(pid) do
    send(pid, :remove_messaging_handler)
    :ok
  end
end

ExUnit.start()
