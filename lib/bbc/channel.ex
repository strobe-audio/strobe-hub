defmodule BBC.Channel do
  defstruct [:id, :title, duration: :infinity]

  alias __MODULE__

  def cover_image(channel, size \\ :large)
  def cover_image(channel, size) do
    Otis.Media.url(BBC.library_id,logo(channel, size))
  end

  def logo(channel, size \\ :large)
  def logo(%Channel{id: id}, size) do
    "#{id}.#{size}.svg"
  end
end

defimpl Poison.Encoder, for: BBC.Channel do
  @fields [
    :id,
    :album,
    :bit_rate,
    :channels,
    :composer,
    :date,
    :disk_number,
    :disk_total,
    :duration_ms,
    :extension,
    :filename,
    :genre,
    :mime_type,
    :performer,
    :sample_rate,
    :stream_size,
    :title,
    :track_number,
    :track_total,
    :cover_image,
  ]

  # Elm is expecting these fields to be present so let's start with a struct
  # that contains a blank version of everything.
  @prototype Enum.map(@fields, fn(key) -> {key, nil} end) |> Enum.into(%{})

  def encode(channel, opts) do
    channel
    |> Map.take(@fields)
    |> Enum.into(@prototype)
    |> Map.put(:cover_image, BBC.Channel.cover_image(channel))
    |> Poison.Encoder.encode(opts)
  end
end

defimpl Otis.Library.Source, for: BBC.Channel do
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

  def pause(_channel, _stream_id, _stream) do
    :stop
  end

  def close(_channel, stream_id, _stream) do
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

defimpl Otis.Library.Source.Origin, for: BBC.Channel do
  def load!(bbc) do
    BBC.find!(bbc)
  end
end
