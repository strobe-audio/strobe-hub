defmodule Peel.Track do
  use    Ecto.Schema
  import Ecto.Query

  alias  Peel.Repo
  alias  Peel.Track
  alias  Peel.Album
  alias  Peel.Artist

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

    # Peel metadata
    field :path, :string
    field :mtime, Ecto.DateTime

    belongs_to :album, Peel.Album
  end

  def first do
    Track |> order_by(:id) |> limit(1) |> Repo.one
  end

  def all do
    Track |> Repo.all
  end

  def create!(track) do
    track |> Repo.insert!
  end

  def from_path(path) do
    Track
    |> where(path: ^path)
    |> limit(1)
    |> Repo.one
  end

  def delete_all do
    Track |> Repo.delete_all
  end

  def lookup_album(track) do
    track |> Album.for_track
  end

  def lookup_artist(track) do
    track |> Artist.for_track
  end
end

