defmodule Test.Otis.Pipeline do

  alias Test.CycleSource
  alias Test.PassthroughTranscoder

  use ExUnit.Case

  test "CycleSource 1 cycle" do
    {:ok, source} = CycleSource.start_link(Enum.to_list(0..4), 1)
    assert {:ok, 0} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(source)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(source)
    assert :done == Otis.Pipeline.Producer.next(source)
  end
  test "CycleSource 2 cycles" do
    {:ok, source} = CycleSource.start_link(Enum.to_list(0..4), 2)
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
    {:ok, source} = CycleSource.start_link(Enum.to_list(0..1), -1)
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
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
    ]
    {:ok, source} = CycleSource.start_link([c1, c2, c3], -1)
    assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c2} == Otis.Pipeline.Producer.next(source)
    assert {:ok, c3} == Otis.Pipeline.Producer.next(source)
  end
  test "CycleSource infinitely repeated binary" do
    [c1] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
    ]
    {:ok, source} = CycleSource.start_link([c1], -1)
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
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
    ]
    {:ok, source} = CycleSource.start_link([c1], 100)
    Enum.each(1..100, fn(_) ->
      assert {:ok, c1} == Otis.Pipeline.Producer.next(source)
    end)
    assert :done == Otis.Pipeline.Producer.next(source)
  end


  test "PassthroughTranscoder" do
    array = CycleSource.new(Enum.to_list(0..4))
    source = Otis.Library.Source.open!(array, "", 1)
    {:ok, trans} = PassthroughTranscoder.start_link(nil, source, 0)

    assert {:ok, 0} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 1} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 2} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 3} == Otis.Pipeline.Producer.next(trans)
    assert {:ok, 4} == Otis.Pipeline.Producer.next(trans)
    assert :done == Otis.Pipeline.Producer.next(trans)
  end
end

