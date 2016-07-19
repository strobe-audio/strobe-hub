defmodule HLS.BBC do
  defstruct [:id]
  require Logger

  @channels ["radio4"]

  def radio4 do
    stream("radio4")
  end

  def open!(%__MODULE__{id: channel}) when channel in @channels do
    hls = stream(channel)
    HLS.Client.open!(hls)
  end

  defp stream(channel) do
    reader = %HLS.Reader.Http{}
    channel |> playlist |> HLS.Stream.new(reader)
  end

  defp playlist(channel) when channel in @channels do
    path = Path.join([__DIR__, "bbc/#{channel}.m3u8"]) |> Path.expand
    file = File.read!(path)
    M3.Parser.parse!(file, "http://www.bbc.co.uk")
  end

  defp playlist(channel) do
    raise "Unknown channel #{inspect channel}"
  end
end

if Code.ensure_loaded?(Otis.Source) do
  defimpl Otis.Source, for: HLS.BBC do
    alias HLS.BBC

    def id(bbc) do
      bbc.id
    end

    def type(_) do
      HLS.BBC
    end

    def open!(bbc, _packet_size_bytes) do
      HLS.BBC.open!(bbc)
    end

    def close(%BBC{}, _stream) do
      # no-op until I can figure out what this should do..
      # release data I suppose but that'll probably just be
      # GC'd
    end

    def audio_type(_bbc) do
      {".mpegts", "audio/mp2t"}
    end

    def metadata(_bbc) do
      %Otis.Source.Metadata{}
    end

    def duration(_bbc) do
      {:ok, :infinity}
    end
  end

  defimpl Otis.Source.Origin, for: HLS.BBC do
    alias HLS.BBC

    def load!(bbc) do
      bbc
    end
  end
end
