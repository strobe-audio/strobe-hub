defmodule Janis.Player.Player do
  @moduledoc """
  Reads audio packets from Janis.Player.Buffer and writes them to the audio hardware
  """

  use     GenServer
  require Logger

  defmodule S do
    defstruct buffer: nil,
              timer:  nil
  end

  def start_link(buffer) do
    GenServer.start_link(__MODULE__, buffer, name: Janis.Player.Player)
  end

  def start_playback(player) do
    GenServer.cast(player, :start_playback)
  end

  def init(buffer) do
    Logger.debug "Player.Player up"
    Janis.Player.Buffer.link_player(buffer, self)
    {:ok, %S{buffer: buffer}}
  end

  def handle_cast(:start_playback, %S{buffer: buffer, timer: nil} = state) do
    {:ok, timer} = Janis.Looper.start_link(buffer, 40)
    {:noreply, %S{ state | timer: timer }}
  end

  def handle_cast(:start_playback, state) do
    {:noreply, state}
  end

  def handle_cast({:play, data}, state) do
    Logger.debug "Play #{inspect data}"
    {:noreply, state}
  end
end
