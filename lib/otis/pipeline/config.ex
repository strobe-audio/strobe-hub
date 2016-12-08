defmodule Otis.Pipeline.Config do

  # Defaults
  @sample_freq        44_100
  @sample_bits        16
  @sample_bytes       round(@sample_bits / 8)
  @sample_channels    2
  @buffer_packets     10
  @receiver_buffer_ms 2_000
  @base_latency_ms    50

  defstruct [
    :packet_size,
    :packet_duration_ms,
    channels: @sample_channels,
    sample_freq: @sample_freq,
    sample_bits: @sample_bits,
    buffer_packets: @buffer_packets,
    receiver_buffer_ms: @receiver_buffer_ms,
    base_latency_ms: @base_latency_ms,
    transcoder: Otis.Pipeline.Transcoder,
  ]

  def new(packet_duration_ms) do
    bps = @sample_freq * @sample_bytes * @sample_channels
    packet_size = round(bps * (packet_duration_ms / 1000))
    %__MODULE__{
      packet_size: packet_size,
      packet_duration_ms: packet_duration_ms,
    }
  end

  def receiver_buffer_packets(config) do
    div(config.receiver_buffer_ms, config.packet_duration_ms)
  end
end
