defmodule Peel.Track do
  use    Peel.Model

  alias  Peel.Repo
  alias  Peel.Track
  alias  Peel.Album
  alias  Peel.Artist

  @primary_key {:id, :binary_id, autogenerate: true}

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

    belongs_to :album, Peel.Album, type: Ecto.UUID
  end

  def create!(track) do
    track |> Repo.insert!
  end

  def new(path) do
    new(path, File.stat!(path))
  end
  def new(path, %File.Stat{mtime: mtime}) do
    %Track{
      mtime: Ecto.DateTime.from_erl(mtime),
      path: path
    }
  end

  def from_path(path) do
    Track
    |> where(path: ^path)
    |> limit(1)
    |> Repo.one
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

defimpl Collectable, for: Peel.Track do
  def into(original) do
    {original, fn
      map, {:cont, {k, v}} -> :maps.put(k, v, map)
      map, :done -> map
      _, :halt -> :ok
    end}
  end
end

defimpl Otis.Source, for: Peel.Track do
  alias Peel.Track

  def id(track) do
    track.id
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
end
