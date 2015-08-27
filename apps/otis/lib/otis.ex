defmodule Otis do
  use Application

  @sample_freq 44100
  @sample_bits 16
  @sample_channels 2

  @stream_frame_bits  192
  @stream_frame_bytes 24

  # Final bitrate  is 176,400 Bytes/s
  # So 176400 = @stream_bytes_per_step * ( 1000 / @stream_interval_ms)
  # These numbers are chosen so that the gap between frames is some integer
  # number of milliseconds.

  # The higher the @multiplier the bigger each individual frame is, the longer
  # the gap between frames, the less work the server has to do and (probably)
  # the more reliable and the stream is *but* the longer the gap between
  # pressing stop and hearing the music stop
  @multiplier             2
  @stream_frames_per_step 147  * @multiplier
  @stream_bytes_per_step  3528 * @multiplier
  @stream_interval_ms     20   * @multiplier

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
