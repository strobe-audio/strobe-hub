defmodule Test.Otis.Packet do
  use ExUnit.Case, async: true
  doctest Otis.Packet

  alias Otis.Packet

  test "packet marshalling" do
    data = << "123412341234"::binary >>
    packet = Packet.new("1234", 0, 100, 3528) |> Packet.timestamp(1234987234, 99) |> Packet.attach(data)
    marshalled = Packet.marshal(packet)
    << n::size(64)-little-unsigned-integer, timestamp::size(64)-little-signed-integer, audio::binary >> = marshalled
    assert n == 99
    assert timestamp == 1234987234
    assert audio == data
  end

  test "packet unmarshalling" do
    data = << "123412341234"::binary >>
    original_packet = Packet.new("1234", 0, 100, 3528) |> Packet.timestamp(1234987234, 99) |> Packet.attach(data)
    marshalled = Packet.marshal(original_packet)
    packet = Packet.unmarshal(marshalled)
    %Packet{packet_number: n, timestamp: timestamp, data: audio, packet_size: packet_size} = packet
    assert n == 99
    assert timestamp == 1234987234
    assert audio == data
    assert packet_size == byte_size(data)
  end
end
