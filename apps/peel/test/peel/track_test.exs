defmodule Peel.Test.TrackTest do
  use   ExUnit.Case

  alias Peel.Repo
  alias Peel.Collection
  alias Peel.Track

  test "tracks can return an Otis-friendly extension" do
    track = %Track{path: "this/that/song.m4a"}
    assert Track.extension(track) == "m4a"
  end

  test "tracks return absolute path" do
    collection = %Collection{id: Ecto.UUID.generate(), name: "My Music", path: "/path/to/collection"} |> Repo.insert!
    track = %Track{collection_id: collection.id, path: "my/relative/path.mp3"}
    assert Track.path(track) == "/path/to/collection/my/relative/path.mp3"
  end
end
