defmodule Janis.Player.Buffer do
  use     GenServer
  require Logger

  @moduledoc """
  Receives data from the buffer and passes it onto the playback process on demand
  """

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def link_player(buffer, player) do
    GenServer.cast(buffer, {:link_player, player})
  end

  def get(buffer) do
    GenServer.call(buffer, :get)
  end

  def put(buffer, packet) do
    GenServer.cast(buffer, {:put, packet})
  end

  def init(:ok) do
    Logger.debug "Player.Buffer up"
    {:ok, {:queue.new, nil}}
  end

  def handle_cast({:link_player, player}, {queue, _} = _state) do
    {:noreply, {queue, player}}
  end

  def handle_cast({:put, packet}, {queue, player} = _state) do
    {:noreply, {put_packet(queue, packet, player), player}}
  end

  def handle_call(:get, _from, {queue, _player} = state) do
    {{:value, packet}, queue} = :queue.out(queue)
    {:reply, {:ok, packet}, {queue, _player}}
  end

  def put_packet(queue, packet, player) do
    player_start_playback(player)
    :queue.in(packet, queue)
  end

  def player_start_playback(nil) do
  end

  def player_start_playback(player) do
    Janis.Player.Player.start_playback(player)
  end
end

