defmodule Otis do
  use Application

  @sample_freq 44100
  @sample_bits 16
  @sample_channels 2

  @stream_frame_bits  192
  @stream_frame_bytes 24

  # Final bitrate  is 176,400 Bytes/s
  # So 176400 = @stream_bytes_per_step * ( 1000 / @stream_interval_ms)
  @stream_frames_per_step 147
  @stream_bytes_per_step  3528
  @stream_interval_ms     20

  def sample_freq, do: @sample_freq
  def sample_bits, do: @sample_bits
  def sample_channels, do: @sample_channels

  def stream_interval_ms, do: @stream_interval_ms
  def stream_bytes_per_step, do: @stream_bytes_per_step

  def start(_type, _args) do
    IO.inspect [:Otis, :start]
    Otis.Supervisor.start_link#(zones)
  end
end
