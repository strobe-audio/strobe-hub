defmodule Peel.Track do
  use    Peel.Model

  alias  Peel.Repo
  alias  Peel.Track
  alias  Peel.Album
  alias  Peel.Artist
  alias  Peel.AlbumArtist

  schema "tracks" do
    # Musical info
    field :title, :string
    field :album_title, :string, default: "Unknown Album"

    field :composer, :string, default: "Unknown composer"
    field :date, :string
    field :genre, :string, default: ""
    field :performer, :string, default: "Unknown artist"

    field :disk_number, :integer
    field :disk_total, :integer
    field :track_number, :integer
    field :track_total, :integer

    field :duration_ms, :integer, default: 0
    field :mime_type, :string

    # Peel metadata
    field :path, :string
    field :mtime, Ecto.DateTime
    field :normalized_title, :string

    field :cover_image, :string

    belongs_to :album, Peel.Album, type: Ecto.UUID
    belongs_to :artist, Peel.Artist, type: Ecto.UUID
  end

  def create!(track) do
    track
    |> Album.for_track
    |> Artist.for_track
    |> AlbumArtist.for_track
    |> Repo.insert!
  end

  def album_by_artist(album_id, artist_id) do
    Track
    |> where(album_id: ^album_id, artist_id: ^artist_id)
    |> order_by([:track_number])
    |> Repo.all
  end

  def new(path, metadata) do
    new(path, metadata, File.stat!(path))
  end
  def new(path, metadata, %File.Stat{mtime: mtime}) do
    %Track{
      mtime: Ecto.DateTime.from_erl(mtime),
      path: path
    }
    |> struct(metadata)
    |> normalize
  end

  defp normalize(%Track{ title: nil } = track) do
    normalize(%Track{ track | title: "Untitled" })
  end
  defp normalize(track) do
    %Track{ track | normalized_title: Peel.String.normalize(track.title) }
  end

  def by_path(path) do
    Track
    |> where(path: ^path)
    |> limit(1)
    |> Repo.one
  end

  def album(track) do
    track.album_id |> Album.find
  end

  def lookup_album(track) do
    track |> Album.for_track
  end

  def lookup_artist(track) do
    track |> Artist.for_track
  end

  def extension(%Track{path: path}) do
    path |> Path.extname |> strip_leading_dot
  end
  def strip_leading_dot("." <> rest), do: rest
end

if Code.ensure_loaded?(Otis.Source) do
  defimpl Otis.Source, for: Peel.Track do
    alias Peel.Track

    def id(track) do
      track.id
    end

    def type(_track) do
      Peel.Track
    end

    def open!(%Track{path: path}, packet_size_bytes) do
      Elixir.File.stream!(path, [], packet_size_bytes)
    end

    def close(%Track{}, stream) do
      Elixir.File.close(stream)
    end

    def audio_type(track) do
      {Track.extension(track), track.mime_type}
    end

    # TODO: what should this return?
    def metadata(track) do
      track
    end

    def duration(%Track{duration_ms: duration_ms}) do
      {:ok, duration_ms}
    end
  end

  defimpl Otis.Source.Origin, for: Peel.Track do
    def load!(track) do
      Peel.Track.find(track.id)
    end
  end
end

# TODO: The encoded struct for a source is too fiddly
defimpl Poison.Encoder, for: Peel.Track do
  @metadata_required_fields [
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
  ]
  @blank_metadata Enum.map(@metadata_required_fields, fn(key) -> {key, nil} end) |> Enum.into(%{})

  defp track_metadata(track) do
    track
    |> Map.take(@metadata_required_fields)
    |> Map.put(:album, track.album_title)
    |> Enum.into(@blank_metadata)
  end

  def encode(track, opts) do
    metadata = track_metadata(track)

    track
    |> Map.take([:id])
    |> Map.put(:metadata, metadata)
    |> Poison.Encoder.encode(opts)
  end
end
