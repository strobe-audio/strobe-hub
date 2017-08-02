defmodule Otis.Library.UPNP.ItemTest do
  use ExUnit.Case

  alias Otis.Library.UPNP.{Item, Media}

  setup_all do
    {:ok, _} = :application.ensure_all_started(:httparrot)
    :ok
  end

  test "generates valid ids for source lookup" do
    item = %Item{id: "1$7$F$7", device_id: "uuid:4d696e69-444c-164e-9d41-001c42fc0db6::urn:schemas-upnp-org:device:MediaServer:1"}
    assert Otis.Library.Source.id(item) == "uuid%3A4d696e69-444c-164e-9d41-001c42fc0db6%3A%3Aurn%3Aschemas-upnp-org%3Adevice%3AMediaServer%3A1/1%247%24F%247"
  end

  test "returns correct type & extension info" do
    media = %Media{bitrate: 256_000, channels: 2, duration: "0:02:45.186",
      info: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320;DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000",
      sample_freq: 44_100, size: 6_403_418,
      uri: "http://192.168.1.92:8200/MediaItems/2165.m4a"
    }
    item = %Item{media: media}
    assert Otis.Library.Source.transcoder_args(item) == ["-f", "m4a"]
  end

  test "returns correct duration" do
    media = %Media{bitrate: 256_000, channels: 2, duration: 165_186,
      info: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320;DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000",
      sample_freq: 44_100, size: 6_403_418,
      uri: "http://192.168.1.92:8200/MediaItems/2165.m4a"
    }
    item = %Item{media: media}
    assert Otis.Library.Source.duration(item) == {:ok, 165_186}
  end

  test "streaming data" do
    {n, chunk_size, seed} = {1024, 64, 9999}
    url =  "http://127.0.0.1:8080/stream-bytes/#{n}?seed=#{seed}&chunk_size=#{chunk_size}"
    media = %Media{bitrate: 256_000, channels: 2, duration: "0:02:45.186",
      info: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320;DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000",
      sample_freq: 44_100, size: 6_403_418,
      uri: url
    }
    item = %Item{media: media}
    %HTTPoison.Response{body: expected} = HTTPoison.get!(url)
    stream = Otis.Library.Source.open!(item, "", 64)
    binary = Enum.join(stream, "")
    assert binary == expected
  end
end

