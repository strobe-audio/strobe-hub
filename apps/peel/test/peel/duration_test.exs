defmodule Peel.Test.DurationTest do
  use   ExUnit.Case, async: true

  @test_cases_ms [
    {100, "00:00"},
    {1_000, "00:01"},
    {1_439, "00:01"},
    {1_500, "00:02"},
    {1_999, "00:02"},
    {159_000, "02:39"},
    {639_000, "10:39"},
    {7_839_000, "2:10:39"},
  ]

  Enum.each @test_cases_ms, fn({ms, duration}) ->
    test "hms_ms #{ms}" do
      assert Otis.Library.Duration.hms_ms(unquote(ms)) == unquote(duration)
    end
  end
end
