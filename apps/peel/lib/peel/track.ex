defmodule Peel.Track do
  use Peel.Model

  alias Peel.Repo
  alias Peel.Collection
  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.AlbumArtist
  alias Ecto.Changeset

  schema "tracks" do
    # Musical info
    field(:title, :string)
    field(:album_title, :string, default: "Unknown Album")

    field(:composer, :string, default: "Unknown composer")
    field(:date, :string)
    field(:genre, :string, default: "")
    field(:performer, :string, default: "Unknown artist")

    field(:disk_number, :integer)
    field(:disk_total, :integer)
    field(:track_number, :integer)
    field(:track_total, :integer)

    field(:duration_ms, :integer, default: 0)
    field(:mime_type, :string)

    # Peel metadata
    field(:path, :string)
    field(:mtime, :naive_datetime)
    field(:normalized_title, :string)

    field(:cover_image, :string)

    belongs_to(:collection, Peel.Collection, type: Ecto.UUID)
    belongs_to(:album, Peel.Album, type: Ecto.UUID)
    belongs_to(:artist, Peel.Artist, type: Ecto.UUID)
  end

  def create!(track) do
    track
    |> Album.for_track()
    |> Artist.for_track()
    |> AlbumArtist.for_track()
    |> Repo.insert!()
  end

  def album_by_artist(album_id, artist_id) do
    Track
    |> where(album_id: ^album_id, artist_id: ^artist_id)
    |> order_by([:track_number])
    |> Repo.all()
  end

  def new(path, collection, metadata) do
    # new(path, metadata, File.stat!(path))
    %Track{
      collection_id: collection.id,
      path: path
    }
    |> struct(metadata)
    |> normalize
  end

  # def new(path, metadata, %File.Stat{mtime: mtime}) do
  #   %Track{
  #     mtime: Ecto.DateTime.from_erl(mtime),
  #     path: path
  #   }
  #   |> struct(metadata)
  #   |> normalize
  # end

  defp normalize(%Track{title: nil} = track) do
    normalize(%Track{track | title: "Untitled"})
  end

  defp normalize(track) do
    %Track{track | normalized_title: Peel.String.normalize(track.title)}
  end

  def by_path(path, %Collection{id: collection_id}) do
    Track
    |> where(path: ^path, collection_id: ^collection_id)
    |> limit(1)
    |> Repo.one()
  end

  def under_root(root, %Collection{id: collection_id}) do
    pattern = "#{root}/%"

    from(t in Track, where: like(t.path, ^pattern))
    |> where(collection_id: ^collection_id)
    |> Repo.all()
  end

  def move(track, collection, path) do
    Changeset.change(track, path: path, collection_id: collection.id) |> Repo.update!()
  end

  def artist(track) do
    track.artist_id |> Artist.find()
  end

  def album(track) do
    track.album_id |> Album.find()
  end

  def lookup_album(track) do
    track |> Album.for_track()
  end

  def lookup_artist(track) do
    track |> Artist.for_track()
  end

  def extension(%Track{path: path}) do
    path |> Path.extname() |> strip_leading_dot
  end

  def strip_leading_dot("." <> rest), do: rest

  def search(query, %Collection{id: collection_id}) do
    pattern = "%#{Peel.String.normalize(query)}%"

    from(track in Track, where: like(track.normalized_title, ^pattern))
    |> where(collection_id: ^collection_id)
    |> Repo.all()
  end

  def path(track) do
    track
    |> Repo.preload(:collection)
    |> abs_path()
  end

  defp abs_path(%Track{collection: collection, path: path}) do
    [collection.path, path] |> Path.join()
  end
end

defimpl Otis.Library.Source, for: Peel.Track do
  alias Peel.Track

  def id(track) do
    track.id
  end

  def type(_track) do
    Peel.Track
  end

  def open!(track, _id, packet_size_bytes) do
    track |> Track.path() |> Elixir.File.stream!([], packet_size_bytes)
  end

  def pause(_track, _id, _stream) do
    :ok
  end

  def resume!(_track, _id, stream) do
    {:reuse, stream}
  end

  def close(%Track{}, _id, stream) do
    Elixir.File.close(stream)
  end

  def transcoder_args(track) do
    ["-f", Track.extension(track) |> Otis.Library.strip_leading_dot()]
  end

  # TODO: what should this return?
  def metadata(track) do
    track
  end

  def duration(%Track{duration_ms: duration_ms}) do
    {:ok, duration_ms}
  end
end

defimpl Otis.Library.Source.Origin, for: Peel.Track do
  def load!(track) do
    Peel.Track.find(track.id)
  end
end

defimpl Poison.Encoder, for: Peel.Track do
  @fields [
    :id,
    :album,
    :composer,
    :duration_ms,
    :genre,
    :performer,
    :title,
    :cover_image
  ]

  # Elm is expecting these fields to be present so let's start with a struct
  # that contains a blank version of everything.
  @prototype Enum.map(@fields, fn key -> {key, nil} end) |> Enum.into(%{})

  def encode(track, opts) do
    track
    |> Map.take(@fields)
    |> Enum.into(@prototype)
    |> Map.put(:album, track.album_title)
    |> Poison.Encoder.encode(opts)
  end
end
