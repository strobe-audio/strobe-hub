defmodule Otis.Persistence.PlayListTest do
  use   ExUnit.Case

  alias Otis.State
  alias State.Rendition
  alias State.Playlist
  alias State.Channel

  def ids(renditions), do: Enum.map(List.wrap(renditions), fn(%Rendition{id: id}) -> id end)

  setup_all do
    {:ok, channel_id: Otis.uuid, profile_id: Otis.uuid }
  end

  setup cxt do
    Ecto.Adapters.SQL.restart_test_transaction(State.Repo)
    MessagingHandler.attach

    channel =
      cxt.channel_id
      |> Channel.create!("Test Channel")
      |> Channel.update(profile_id: cxt.profile_id)

    {:ok, channel: channel}
  end

  test "empty state", cxt do
    assert [] == Playlist.list(cxt.channel)
    assert nil == Playlist.last(cxt.channel)
    assert nil == Playlist.current(cxt.channel)
  end

  test "appending to empty list", cxt do
    r = [
      %Rendition{id: "418c93d6-5b1f-11e7-a9a6-002500f418fc" },
      %Rendition{id: "473a50fc-5b1f-11e7-a0d3-002500f418fc" },
    ]
    {channel, inserted} = Playlist.append!(cxt.channel, r)
    assert ids(inserted) == ids(r)
    assert ids(r) == ids(Playlist.list(channel))
  end

  test "prepending to empty list", cxt do
    r = [
      %Rendition{id: "418c93d6-5b1f-11e7-a9a6-002500f418fc" },
      %Rendition{id: "473a50fc-5b1f-11e7-a0d3-002500f418fc" },
    ]
    {channel, inserted} = Playlist.prepend!(cxt.channel, r)
    assert ids(inserted) == ids(r)
    assert ids(r) == ids(Playlist.list(channel))
  end

  describe "with existing entries" do
    setup %{channel_id: id, channel: channel} do
      playlist = [first | _] = [
        %Rendition{channel_id: id, id: "ec779bec-44d9-4a0a-ade5-b6df0eee9571", next_id: "dc1c043e-25ac-463a-8f3c-fd3f79a36897" },
        %Rendition{channel_id: id, id: "dc1c043e-25ac-463a-8f3c-fd3f79a36897", next_id: "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9" },
        %Rendition{channel_id: id, id: "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9", next_id: "06a72197-dc53-40d3-afc4-0121db3271c5" },
        %Rendition{channel_id: id, id: "06a72197-dc53-40d3-afc4-0121db3271c5", next_id: "cc8e2967-a956-47d2-9a5a-549a67aa95b6" },
        %Rendition{channel_id: id, id: "cc8e2967-a956-47d2-9a5a-549a67aa95b6", next_id: "e01985f9-897b-4441-9b41-f1f198a8f7ef" },
        %Rendition{channel_id: id, id: "e01985f9-897b-4441-9b41-f1f198a8f7ef", next_id: "99933b7d-ed14-495d-b8ca-f8ce37135474" },
        %Rendition{channel_id: id, id: "99933b7d-ed14-495d-b8ca-f8ce37135474", next_id: "9048382e-df62-4932-819b-2d7f4a9d5d8f" },
        %Rendition{channel_id: id, id: "9048382e-df62-4932-819b-2d7f4a9d5d8f", next_id: "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb" },
        %Rendition{channel_id: id, id: "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb" },
      ]

      renditions = for r <- Enum.reverse(playlist) do
        Rendition.create!(r)
      end |> Enum.reverse()

      channel =
        channel
        |> Channel.update(current_rendition_id: first.id)

      {:ok, channel: channel, renditions: renditions}
    end

    test "current rendition", %{renditions: [first | _]} = cxt do
      assert first == Playlist.current(cxt.channel)
    end

    test "listing renditions", cxt do
      assert Playlist.list(cxt.channel) == cxt.renditions
    end

    test "mapping renditions", cxt do
      assert ids(cxt.renditions) == Playlist.map(cxt.channel, fn(r) -> r.id end)
    end

    test "streaming renditions", cxt do
      assert ids(Enum.at(cxt.renditions, 2)) == Playlist.stream(cxt.channel) |> Enum.at(2) |> ids()
    end

    test "last", cxt do
      assert Playlist.last(cxt.channel) ==  List.last(cxt.renditions)
    end

    test "appending to list", cxt do
      r = [
        %Rendition{id: "418c93d6-5b1f-11e7-a9a6-002500f418fc" },
        %Rendition{id: "473a50fc-5b1f-11e7-a0d3-002500f418fc" },
      ]
      {channel, inserted} = Playlist.append!(cxt.channel, r)
      assert ids(inserted) == ids(r)
      assert (ids(cxt.renditions) ++ ids(r)) == ids(Playlist.list(channel))
    end

    test "prepending to list", cxt do
      r = [
        %Rendition{id: "418c93d6-5b1f-11e7-a9a6-002500f418fc" },
        %Rendition{id: "473a50fc-5b1f-11e7-a0d3-002500f418fc" },
      ]
      {channel, inserted} = Playlist.prepend!(cxt.channel, r)
      assert ids(inserted) == ids(r)
      assert (ids(r) ++ ids(cxt.renditions)) == ids(Playlist.list(channel))
    end

    test "inserting into list", cxt do
      r = [
        %Rendition{id: "418c93d6-5b1f-11e7-a9a6-002500f418fc" },
        %Rendition{id: "473a50fc-5b1f-11e7-a0d3-002500f418fc" },
      ]
      {channel, inserted} = Playlist.insert_after!(cxt.channel, "cc8e2967-a956-47d2-9a5a-549a67aa95b6", r)
      assert ids(inserted) == ids(r)
      ids = [
        "ec779bec-44d9-4a0a-ade5-b6df0eee9571",
        "dc1c043e-25ac-463a-8f3c-fd3f79a36897",
        "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9",
        "06a72197-dc53-40d3-afc4-0121db3271c5",
        "cc8e2967-a956-47d2-9a5a-549a67aa95b6",
        # inserted
        "418c93d6-5b1f-11e7-a9a6-002500f418fc",
        "473a50fc-5b1f-11e7-a0d3-002500f418fc",

        "e01985f9-897b-4441-9b41-f1f198a8f7ef",
        "99933b7d-ed14-495d-b8ca-f8ce37135474",
        "9048382e-df62-4932-819b-2d7f4a9d5d8f",
        "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb",
      ]
      assert ids == ids(Playlist.list(channel))
    end

    test "skipping", cxt do
      skip_to = Enum.at(cxt.renditions, 4)
      {channel, skipped} = Playlist.advance!(cxt.channel, skip_to.id)
      assert ids(skipped) == ids(Enum.slice(cxt.renditions, 0..3))
      assert Playlist.list(channel) == Enum.slice(cxt.renditions, 4..-1)
    end

    test "deleting", cxt do
      start = Enum.at(cxt.renditions, 2)
      delete = Enum.slice(cxt.renditions, 2..5)

      {channel, deleted} = Playlist.delete!(cxt.channel, start.id, 4)
      assert ids(deleted) == ids(delete)
      assert Enum.map(ids(deleted), &Rendition.find/1) == List.duplicate(nil, 4)
      ids = [
        "ec779bec-44d9-4a0a-ade5-b6df0eee9571",
        "dc1c043e-25ac-463a-8f3c-fd3f79a36897",
        # "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9",
        # "06a72197-dc53-40d3-afc4-0121db3271c5",
        # "cc8e2967-a956-47d2-9a5a-549a67aa95b6",
        # "e01985f9-897b-4441-9b41-f1f198a8f7ef",
        "99933b7d-ed14-495d-b8ca-f8ce37135474",
        "9048382e-df62-4932-819b-2d7f4a9d5d8f",
        "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb",
      ]
      assert ids == ids(Playlist.list(channel))
    end

    test "deleting from start", cxt do
      start = Enum.at(cxt.renditions, 0)
      delete = Enum.slice(cxt.renditions, 0..2)

      {channel, deleted} = Playlist.delete!(cxt.channel, start.id, 3)
      assert ids(deleted) == ids(delete)
      assert Enum.map(ids(deleted), &Rendition.find/1) == List.duplicate(nil, 3)
      ids = [
        # "ec779bec-44d9-4a0a-ade5-b6df0eee9571",
        # "dc1c043e-25ac-463a-8f3c-fd3f79a36897",
        # "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9",
        "06a72197-dc53-40d3-afc4-0121db3271c5",
        "cc8e2967-a956-47d2-9a5a-549a67aa95b6",
        "e01985f9-897b-4441-9b41-f1f198a8f7ef",
        "99933b7d-ed14-495d-b8ca-f8ce37135474",
        "9048382e-df62-4932-819b-2d7f4a9d5d8f",
        "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb",
      ]
      assert channel.current_rendition_id == "06a72197-dc53-40d3-afc4-0121db3271c5"
      assert ids == ids(Playlist.list(channel))
    end

    test "deleting head with history", cxt do
      _previous = %Rendition{
        channel_id: cxt.channel_id,
        id: "6a63f1ea-6b06-11e7-871f-002500f418fc",
        next_id: "ec779bec-44d9-4a0a-ade5-b6df0eee9571"
      } |> Rendition.create!

      start = Enum.at(cxt.renditions, 0)
      delete = [start]

      assert cxt.channel.current_rendition_id == "ec779bec-44d9-4a0a-ade5-b6df0eee9571"
      {channel, deleted} = Playlist.delete!(cxt.channel, start.id, 1)
      assert ids(deleted) == ids(delete)
      assert Enum.map(ids(deleted), &Rendition.find/1) == List.duplicate(nil, 1)
      ids = [
        # "ec779bec-44d9-4a0a-ade5-b6df0eee9571",
        "dc1c043e-25ac-463a-8f3c-fd3f79a36897",
        "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9",
        "06a72197-dc53-40d3-afc4-0121db3271c5",
        "cc8e2967-a956-47d2-9a5a-549a67aa95b6",
        "e01985f9-897b-4441-9b41-f1f198a8f7ef",
        "99933b7d-ed14-495d-b8ca-f8ce37135474",
        "9048382e-df62-4932-819b-2d7f4a9d5d8f",
        "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb",
      ]
      assert channel.current_rendition_id == "dc1c043e-25ac-463a-8f3c-fd3f79a36897"
      assert ids == ids(Playlist.list(channel))
    end

    test "deleting entire list", cxt do
      start = Enum.at(cxt.renditions, 0)
      delete = cxt.renditions

      {channel, deleted} = Playlist.delete!(cxt.channel, start.id, 90)
      assert ids(deleted) == ids(delete)
      assert Enum.map(ids(deleted), &Rendition.find/1) == List.duplicate(nil, 9)
      assert [] == ids(Playlist.list(channel))
      assert channel.current_rendition_id == nil
    end

    test "deleting to end", cxt do
      start = Enum.at(cxt.renditions, 4)
      delete = Enum.slice(cxt.renditions, 4..-1)

      {channel, deleted} = Playlist.delete!(cxt.channel, start.id, 5)
      assert ids(deleted) == ids(delete)
      assert Enum.map(ids(deleted), &Rendition.find/1) == List.duplicate(nil, 5)
      ids = [
        "ec779bec-44d9-4a0a-ade5-b6df0eee9571",
        "dc1c043e-25ac-463a-8f3c-fd3f79a36897",
        "f3a74de1-3c68-45d4-bb92-e1ad5f9224f9",
        "06a72197-dc53-40d3-afc4-0121db3271c5",
        # "cc8e2967-a956-47d2-9a5a-549a67aa95b6",
        # "e01985f9-897b-4441-9b41-f1f198a8f7ef",
        # "99933b7d-ed14-495d-b8ca-f8ce37135474",
        # "9048382e-df62-4932-819b-2d7f4a9d5d8f",
        # "f6025f92-e6b5-4f2e-b45e-21fc3f6d09cb",
      ]
      assert ids == ids(Playlist.list(channel))
      last = Rendition.find("06a72197-dc53-40d3-afc4-0121db3271c5")
      assert last.next_id == nil
      assert channel.current_rendition_id == "ec779bec-44d9-4a0a-ade5-b6df0eee9571"
    end

    test "advancing to end", cxt do
      {channel, skipped} = Playlist.advance!(cxt.channel, nil)
      assert ids(skipped) == ids(cxt.renditions)
      assert [] == ids(Playlist.list(channel))
    end

    test "rewinding", cxt do
      {channel, _skipped} = Playlist.advance!(cxt.channel, "cc8e2967-a956-47d2-9a5a-549a67aa95b6")
      stream = Playlist.stream_reverse(channel)
      history = Enum.take(stream, 5)
      assert ids(history) == ids(Enum.slice(cxt.renditions, 0..3) |> Enum.reverse())
    end

    test "rewinding from empty", cxt do
      {channel, _skipped} = Playlist.advance!(cxt.channel, nil)
      assert [] == ids(Playlist.list(channel))
      stream = Playlist.stream_reverse(channel)
      history = Enum.take(stream, 5)
      assert ids(history) == ids(Enum.slice(cxt.renditions, 4..-1) |> Enum.reverse())
    end

    test "rewinding all the way", cxt do
      {channel, _skipped} = Playlist.advance!(cxt.channel, nil)
      assert [] == ids(Playlist.list(channel))
      stream = Playlist.stream_reverse(channel)
      history = Enum.to_list(stream)
      assert ids(history) == ids(cxt.renditions |> Enum.reverse())
    end

    test "clearing all", cxt do
      {channel, deleted} = Playlist.clear!(cxt.channel)
      assert ids(deleted) == ids(cxt.renditions)
      assert [] == ids(Playlist.list(channel))
      assert channel.current_rendition_id == nil
    end

    test "clearing all but active", cxt do
      [active|to_delete] = ids(cxt.renditions)
      {channel, deleted} = Playlist.clear!(cxt.channel, active)
      assert ids(deleted) == to_delete
      assert [active] == ids(Playlist.list(channel))
      assert channel.current_rendition_id == active
    end
  end
end
