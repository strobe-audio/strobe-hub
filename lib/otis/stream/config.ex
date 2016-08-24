defmodule Otis.Stream.Config do
  defstruct [:size, :stream_bytes_per_step, :interval_ms, buffer_seconds: 1]

  def seconds(buffer_seconds, stream_bytes_per_step \\ Otis.stream_bytes_per_step, stream_interval_ms \\ Otis.stream_interval_ms)
  def seconds(buffer_seconds, stream_bytes_per_step, interval_ms) do
    new(buffer_size(buffer_seconds, interval_ms), stream_bytes_per_step, interval_ms)
  end

  def new(size, stream_bytes_per_step \\ Otis.stream_bytes_per_step, stream_interval_ms \\ Otis.stream_interval_ms)
  def new(size, stream_bytes_per_step, interval_ms) do
    %__MODULE__{size: size, stream_bytes_per_step: stream_bytes_per_step, interval_ms: interval_ms}
  end

  def buffer_size(seconds, interval_ms) do
    round((seconds * 1000) / interval_ms)
  end
end
