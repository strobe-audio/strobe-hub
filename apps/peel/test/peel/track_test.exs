defmodule Peel.Test.TrackTest do
  use   ExUnit.Case

  alias Peel.Track

  test "tracks can return an Otis-friendly extension" do
    track = %Track{path: "/this/that/song.m4a"}
    assert Track.extension(track) == "m4a"
  end
end
