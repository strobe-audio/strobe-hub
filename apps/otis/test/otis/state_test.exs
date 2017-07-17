defmodule Otis.StateTest do
  use ExUnit.Case

  alias Otis.Test.TestSource

  def ids(list), do: Enum.map(list, &id/1)
  def id(%{id: id}), do: id

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach()
    :ok
  end

  describe "renditions" do
    setup do
      channels = Enum.map(0..1, fn(n) ->
        {:ok, channel} = Otis.Channels.create("Channel #{n}")
        sources = [TestSource.new, TestSource.new, TestSource.new]
        Otis.Channel.append(channel, sources)
        assert_receive {:new_rendition_created, _}
        assert_receive {:new_rendition_created, _}
        assert_receive {:new_rendition_created, _}
        channel
      end)

      playlists = for c <- channels do
        {:ok, playlist} = Otis.Channel.playlist(c)
        playlist
      end

      {:ok, channels: channels, playlists: playlists}
    end

    test "order", cxt do
      [playlist1, playlist2] = cxt.playlists

      {:ok, renditions1} = Otis.Pipeline.Playlist.list(playlist1)
      {:ok, renditions2} = Otis.Pipeline.Playlist.list(playlist2)

      [state1, state2] = Otis.State.renditions() |> Enum.chunk_by(&(&1.channel_id))

      assert ids(state1) == renditions1
      assert ids(state2) == renditions2
    end

    test "active status", cxt do
      [playlist1, playlist2] = cxt.playlists

      {:ok, active1} = Otis.Pipeline.Playlist.next(playlist1)
      {:ok, active2} = Otis.Pipeline.Playlist.next(playlist2)

      [[first1 | rest1], [first2 | rest2]] = Otis.State.renditions() |> Enum.chunk_by(&(&1.channel_id))

      assert first1.id == active1
      assert first2.id == active2

      assert first1.active
      assert first2.active

      for r <- rest1, do: refute r.active
      for r <- rest2, do: refute r.active
    end

    test "active status serialisation", cxt do
      [playlist1, _playlist2] = cxt.playlists
      {:ok, _active1} = Otis.Pipeline.Playlist.next(playlist1)
      [first | [second | _]] = Otis.State.renditions()
      assert first.active
      refute second.active
      decoded = first |> Poison.encode!() |> Poison.decode!()
      assert decoded["active"] == true
      decoded = second |> Poison.encode!() |> Poison.decode!()
      assert decoded["active"] == false
    end
  end
end
