defmodule Otis.Packet do
  @moduledoc """
  Represents a single chunk of audio as it moves through the pipeline.
  """

  defstruct [
    rendition_id:     nil,
    source_index:  0,
    offset_ms:     0,
    duration_ms:   0,
    packet_size:   0, # the size of each packet in bytes
    packet_number: 0,
    timestamp:     0,
    data:          nil,
  ]

  alias __MODULE__, as: P

  def new(rendition_id, offset_ms, duration_ms, packet_size) do
    %P{rendition_id: rendition_id, offset_ms: offset_ms, duration_ms: duration_ms, packet_size: packet_size}
  end

  @doc ~S"""
  Attaches the given data to the packet.

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> Otis.Packet.attach(packet, <<"whoosh">>)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, data: <<"whoosh">> }

  """
  def attach(packet, data) do
    %P{ packet | data: data }
  end

  @doc ~S"""
  Attaches the given data to the packet.

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> Otis.Packet.attach(packet, <<"whoosh">>, 99, 1234987234)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, data: <<"whoosh">>, timestamp: 1234987234, packet_number: 99 }

  """
  def attach(packet, data, packet_number, timestamp) do
    %P{ packet | data: data, packet_number: packet_number, timestamp: timestamp }
  end

  @doc ~S"""
  Sets the packet's timestamp.

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> Otis.Packet.timestamp(packet, 1234987234)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, timestamp: 1234987234 }

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> Otis.Packet.timestamp(packet, 1234987234, 99)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, timestamp: 1234987234, packet_number: 99 }

  """
  def timestamp(packet, timestamp) do
    %P{ packet | timestamp: timestamp }
  end

  def timestamp(packet, timestamp, packet_number) do
    %P{packet | packet_number: packet_number} |> timestamp(timestamp)
  end

  @doc ~S"""
  Tests to see if the given packet will have been played by the given time.

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> packet = Otis.Packet.timestamp(packet, 1234987234)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, timestamp: 1234987234 }
      iex> Otis.Packet.played?(packet, 1234987233)
      false
      iex> Otis.Packet.played?(packet, 1234987235)
      true
      iex> Otis.Packet.played?(packet, 1234987234)
      true

  """
  def played?(packet, time) do
    packet.timestamp <= time
  end

  def unplayed?(packet, time) do
    !played?(packet, time)
  end

  @doc ~S"""
  Tests to see if the given packet belongs to the given source.

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> Otis.Packet.from_source?(packet, "2222")
      false
      iex> Otis.Packet.from_source?(packet, "1235")
      false
      iex> Otis.Packet.from_source?(packet, "1234")
      true

  """
  def from_source?(packet, rendition_id) do
    packet.rendition_id == rendition_id
  end

  @doc ~S"""
  Resets a packet back to a pristine state (no timestamp).

      iex> packet = Otis.Packet.new("1234", 0, 100, 3528)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }
      iex> packet = Otis.Packet.timestamp(packet, 12341234)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, timestamp: 12341234 }
      iex> packet = %Otis.Packet{ packet | packet_number: 1234 }
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0, timestamp: 12341234, packet_number: 1234 }
      iex> Otis.Packet.reset!(packet)
      %Otis.Packet{ rendition_id: "1234", offset_ms: 0, duration_ms: 100, packet_size: 3528, source_index: 0 }

  """
  def reset!(packet) do
    struct P, Map.drop(packet, [:timestamp, :packet_number, :__struct__])
  end

  @doc "Marshals a packet into a binary blob for sending over the wire"
  def marshal(%P{timestamp: timestamp, packet_number: n, data: data} = _packet) do
    << n         :: size(64)-little-unsigned-integer,
       timestamp :: size(64)-little-signed-integer,
       data      :: binary
    >>
  end

  def unmarshal(data) do
    << n         :: size(64)-little-unsigned-integer,
       timestamp :: size(64)-little-signed-integer,
       audio     :: binary
    >> = data
    %P{packet_size: byte_size(audio), timestamp: timestamp, packet_number: n, data: audio}
  end

  def percent_complete(packet) do
    packet.offset_ms / packet.duration_ms
  end
end
