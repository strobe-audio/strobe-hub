defmodule Test.Otis.Pipeline do
  alias Test.CycleSource
  alias Test.PassthroughTranscoder
  alias Otis.State.Rendition
  alias Otis.Library.Source

  use ExUnit.Case

  setup_all do
    CycleSource.start_table()
    :ok
  end

  test "CycleSource loading" do
    source = CycleSource.new([1, 2, 3], 1) |> CycleSource.save()
    {:ok, source} = CycleSource.find(source.id)
    assert source.source == [1, 2, 3]
  end

  test "CycleSource renditions" do
    source = CycleSource.new([1, 2, 3], 1) |> CycleSource.save()

    rendition =
      %Rendition{
        id: Otis.uuid(),
        channel_id: Otis.uuid(),
        source_type: Source.type(source),
        source_id: Source.id(source),
        playback_duration: 1000,
        playback_position: 0,
        position: 0
      }
      |> Rendition.create!()

    rendition_source = Rendition.source(rendition)
    assert source == rendition_source
  end

  test "CycleSource open" do
    source = CycleSource.new(Enum.to_list(0..4), 1) |> CycleSource.save()
    {:ok, source} = CycleSource.find(source.id)
    stream = Source.open!(source, Otis.uuid(), 1024)
    assert [0, 1, 2, 3, 4] == Enum.to_list(stream)
  end

  test "CycleSource 1 cycle" do
    {:ok, source} = CycleSource.new(Enum.to_list(0..4), 1) |> CycleSource.start_link()
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(source)
    assert :done == Otis.Pipeline.Producer.next(source)
  end

  test "CycleSource 2 cycles" do
    {:ok, source} = CycleSource.new(Enum.to_list(0..4), 2) |> CycleSource.start_link()
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(source)
    assert :done == Otis.Pipeline.Producer.next(source)
  end

  test "CycleSource infinite cycles" do
    {:ok, source} = CycleSource.new(Enum.to_list(0..1), -1) |> CycleSource.start_link()
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
  end

  test "CycleSource binaries" do
    [c1, c2, c3] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>
    ]

    {:ok, source} = CycleSource.new([c1, c2, c3], -1) |> CycleSource.start_link()
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c3} == Otis.Pipeline.Producer.next(source)
  end

  test "CycleSource infinitely repeated binary" do
    [c1] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>
    ]

    {:ok, source} = CycleSource.new([c1], -1) |> CycleSource.start_link()
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
  end

  test "CycleSource repeated binary" do
    [c1] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>
    ]

    {:ok, source} = CycleSource.new([c1], 100) |> CycleSource.start_link()

    Enum.each(1..100, fn _ ->
      assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    end)

    assert :done == Otis.Pipeline.Producer.next(source)
  end

  test "Cyclesource pause with parent process" do
    source = CycleSource.new(Enum.to_list(1..10), 100)
    Otis.Library.Source.pause(source, nil, nil)
    # assert_receive {:source, :pause}
  end

  test "Cyclesource file pause" do
    source = CycleSource.new(Enum.to_list(1..10), 100, :file)
    assert :ok == Otis.Library.Source.pause(source, nil, :stream)
  end

  test "Cyclesource live pause" do
    source = CycleSource.new(Enum.to_list(1..10), 100, :live)
    assert :stop == Otis.Library.Source.pause(source, nil, :stream)
  end

  test "CycleSource file duration" do
    source = CycleSource.new(Enum.to_list(1..10), 100)
    assert {:ok, 100_000} == Otis.Library.Source.duration(source)
  end

  test "CycleSource live duration" do
    source = CycleSource.new(Enum.to_list(1..10), 100, :live)
    assert {:ok, :infinity} == Otis.Library.Source.duration(source)
  end

  test "CycleSource with delay" do
    {:ok, source} =
      CycleSource.new(Enum.to_list(1..10), 100, :live, 50) |> CycleSource.start_link()

    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
  end

  test "PassthroughTranscoder" do
    array = CycleSource.new(Enum.to_list(0..4))
    source = Otis.Library.Source.open!(array, "", 1)
    {:ok, trans} = PassthroughTranscoder.start_link(nil, source, 0, nil)

    assert {:ok, 0} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(trans)
    assert :done == Otis.Pipeline.Producer.next(trans)
  end
end
