defmodule Peel.Modifications.MoveTest do
  use ExUnit.Case

  alias Peel.Track

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join |> Path.expand
  @milkman  [
    "01 Milk Man",
    "02 Giga Dance",
    "03 Desapareceré",
  ] |> Enum.map(&Path.join([@fixtures, "Deerhoof/Milk Man/#{&1}.mp3"]))

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    TestEventHandler.attach([Peel.Webdav.Modifications])
    :ok
  end

  test "move single file" do
    [path1, _, _] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path1]})
    assert_receive {:complete, {:create, [^path1]}}, 500

    destination =  "/tmp/other/#{Path.basename(path1)}"
    Peel.Webdav.Modifications.notify({:move, [:file, path1, destination]})
    assert_receive {:complete, {:move, [:file, ^path1, ^destination]}}, 500

    [track] = Track.all
    assert track.path == destination
  end

  test "move directory" do
    [path1, path2, path3] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path1]})
    Peel.Webdav.Modifications.notify({:create, [path2]})
    Peel.Webdav.Modifications.notify({:create, [path3]})
    assert_receive {:complete, {:create, [^path1]}}, 500
    assert_receive {:complete, {:create, [^path2]}}, 500
    assert_receive {:complete, {:create, [^path3]}}, 500

    src = [@fixtures, "Deerhoof"] |> Path.join
    dst = ["/tmp", "Deerhoof"] |> Path.join
    Peel.Webdav.Modifications.notify({:move, [:directory, src, dst]})
    assert_receive {:complete, {:move, [:directory, ^src, ^dst]}}, 500
    [track1, track2, track3] = Track.all
    assert track1.path == [dst, "Milk Man/01 Milk Man.mp3"] |> Path.join
    assert track2.path == [dst, "Milk Man/02 Giga Dance.mp3"] |> Path.join
    assert track3.path == [dst, "Milk Man/03 Desapareceré.mp3"] |> Path.join
  end
end
