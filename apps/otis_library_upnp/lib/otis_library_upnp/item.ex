defmodule Otis.Library.UPNP.Item do
    defstruct [
      :id,
      :device_id,
      :parent_id,
      :title,
      :album,
      :composer,
      :date,
      :genre,
      :artist,
      :album_art,
      :media,
    ]
    def source_url(%__MODULE__{media: media}) do
      media.uri
    end
end

defimpl Otis.Library.Source, for: Otis.Library.UPNP.Item do
  alias Otis.Library.UPNP
  alias UPNP.{Item, Media}


  def id(%Item{device_id: device_id, id: id}) do
    UPNP.Source.id(device_id, id)
  end

  def type(_item) do
    UPNP.Source
  end

  def open!(%Item{} = item, _id, _packet_size_bytes) do
    {:ok, producer} = UPNP.Source.Stream.start_link(item)
    GenStage.stream([{producer, [max_demand: 1, cancel: :transient]}])
  end

  def pause(_item, _id, _stream) do
    :ok
  end

  def resume!(_item, _id, stream) do
    {:reuse, stream}
  end

  def close(%Item{}, _id, _stream) do
  end

  def transcoder_args(%Item{media: %Media{uri: uri}}) do
    ["-f", Path.extname(uri) |> Otis.Library.strip_leading_dot]
  end

  def metadata(item) do
    %{id: item.id,
      bit_rate: item.media.bitrate,
      channels: item.media.channels,
      duration_ms: Media.duration_ms(item.media),
      extension: nil,
      filename: nil,
      mime_type: nil,
      sample_rate: nil,
      stream_size: item.media.size,
      album: item.album,
      composer: item.composer,
      date: item.date,
      disk_number: nil,
      genre: item.genre,
      performer: item.artist,
      title: item.title,
      track_number: nil,
      track_total: nil,
      cover_image: item.album_art,
    }
  end

  def duration(%Item{media: media}) do
    {:ok, Media.duration_ms(media)}
  end

  def activate(_item, _channel_id) do
    :ok
  end

  def deactivate(_track, _channel_id) do
    :ok
  end
end

defimpl Poison.Encoder, for: Otis.Library.UPNP.Item do
  alias Otis.Library.UPNP.Media

  def encode(item, opts) do
    %{id: item.id,
      bit_rate: item.media.bitrate,
      channels: item.media.channels,
      duration_ms: Media.duration_ms(item.media),
      extension: nil,
      filename: nil,
      mime_type: nil,
      sample_rate: nil,
      stream_size: item.media.size,
      album: item.album,
      composer: item.composer,
      date: item.date,
      disk_number: nil,
      disk_total: nil,
      genre: item.genre,
      performer: item.artist,
      title: item.title,
      track_number: nil,
      track_total: nil,
      cover_image: item.album_art,
    } |> Poison.Encoder.encode(opts)
  end
end
