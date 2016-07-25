defmodule HLS.BBC.Channel do
  defstruct [:id, :title, duration: :infinity]
end


if Code.ensure_loaded?(Otis.Source) do
  defimpl Otis.Source, for: HLS.BBC.Channel do
    alias HLS.BBC

    def id(bbc) do
      bbc.id
    end

    def type(_bbc) do
      BBC.Channel
    end

    def open!(bbc, id, _packet_size_bytes) do
      BBC.open!(bbc, id)
    end

    def pause(bbc, id, stream) do
      BBC.pause(bbc, id, stream)
    end

    def resume!(bbc, id, stream) do
      BBC.resume!(bbc, id, stream)
    end

    def close(bbc, id, stream) do
      BBC.close(bbc, id, stream)
    end

    def audio_type(_bbc) do
      {".mpegts", "audio/mp2t"}
    end

    def metadata(_bbc) do
      %Otis.Source.Metadata{}
    end

    def duration(channel) do
      {:ok, channel.duration}
    end
  end

  defimpl Otis.Source.Origin, for: HLS.BBC.Channel do
    def load!(bbc) do
      HLS.BBC.find!(bbc)
    end
  end
end
