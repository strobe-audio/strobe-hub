defmodule Otis.Packet do

  defstruct [
    :source_id,
    :duration,
    :packet_size, # the size of each packet in bytes
    position: 0,
    index: 0,
  ]

  alias __MODULE__, as: P

  def new(source_id, position, duration, packet_size) do
    %P{source_id: source_id, position: position, duration: duration, packet_size: packet_size}
  end

  @doc ~S"""
  Updates a packet's position by one audio frame:

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ source_id: "1234", position: 0, duration: 100, packet_size: 3528, index: 0 }
      iex> packet = Otis.Packet.step(packet)
      %Otis.Packet{ source_id: "1234", position: 20.0, duration: 100, packet_size: 3528, index: 1 }
      iex> _packet = Otis.Packet.step(packet)
      %Otis.Packet{ source_id: "1234", position: 40.0, duration: 100, packet_size: 3528, index: 2 }

      iex> packet = Otis.Packet.new("1234", 0, 10000, 17640)
      %Otis.Packet{ source_id: "1234", position: 0, duration: 10000, packet_size: 17640, index: 0 }
      iex> packet = Otis.Packet.step(packet)
      %Otis.Packet{ source_id: "1234", position: 100.0, duration: 10000, packet_size: 17640, index: 1 }
      iex> _packet = Otis.Packet.step(packet)
      %Otis.Packet{ source_id: "1234", position: 200.0, duration: 10000, packet_size: 17640, index: 2 }

  """
  def step(packet) do
    %P{ packet | index: packet.index + 1, position: step_position(packet) }
  end

  def percent_complete(packet) do
    packet.position / packet.duration
  end

  def step_position(packet) do
    packet.position + packet_size_to_step_duration(packet.packet_size)
  end

  def packet_size_to_step_duration(packet_size) do
    1000 * (packet_size / (Otis.stream_bytes_per_second))
  end
end
