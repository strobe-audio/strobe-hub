defmodule Peel.Test.StringTest do
  use   ExUnit.Case, async: true

  @test_cases [
    [
      "this that", [
        "This That",
        "THIS THAT",
        "this that",
        "this that",
        "this  that",
        " this  that  ",
      ]
    ],
    [
      "bela bartok", [ "Béla Bartók" ]
    ],
    [
      "bjork", [ "Björk", "Bjork" ]
    ],
    [
      "john and paul", [ "john & paul", "john &amp; paul", "john &amp paul" ]
    ],
    [
      "john paul", [
        "john. paul",
        "john, paul",
        "john! paul!",
        "john - paul!",
        "john - [paul!]",
        "john {paul}",
        "john (paul)",
        "john paul...",
        "john paul…",
      ]
    ],
    [
      "count to 10", [ "Count to 10" ]
    ],
    [
      "wiener philharmoniker franz lehar", [ "Wiener Philharmoniker/Franz Lehár" ]
    ],
  ]

  Enum.each @test_cases, fn([expected, cases]) ->
    Enum.each Enum.with_index(cases), fn({test, n}) ->
      test "'#{expected}' #{n}" do
        assert Peel.String.normalize(unquote(test)) == unquote(expected)
      end
    end
  end
end
