defmodule BBC.Source do
  alias HLS.Client.Registry

  def id(bbc) do
    bbc.id
  end

  def type(_bbc) do
    BBC.Channel
  end

  def open!(channel, stream_id, _packet_size_bytes) do
    {:ok, stream} = open(channel, stream_id)
    stream
  end

  def open(channel, stream_id) do
    hls = stream(channel)
    HLS.Client.open!(hls, stream_id)
  end

  defp stream(channel) do
    channel |> BBC.playlist |> HLS.Stream.new(%HLS.Reader.Http{})
  end

  def pause(_channel, stream_id, _stream) do
    HLS.Client.stop(stream_id)
    :ok
  end

  def resume!(channel, stream_id, stream) do
    resume(channel, stream_id, stream, Registry.whereis_name(stream_id))
  end

  def resume(channel, stream_id, _stream, :undefined) do
    {:ok, stream} = open(channel, stream_id)
    {:reopen, stream}
  end
  def resume(_channel, _stream_id, stream, pid) when is_pid(pid) do
    {:reuse, stream}
  end

  def close(_channel, stream_id, _stream) do
    HLS.Client.stop(stream_id)
    :ok
  end

  def audio_type(_bbc) do
    {".mpegts", "audio/mp2t"}
  end

  def metadata(_bbc) do
    %{}
  end

  def duration(channel) do
    {:ok, channel.duration}
  end
end

defmodule BBC.Source.Origin do
  def load!(bbc) do
    BBC.find!(bbc)
  end
end
