defmodule Peel.Test.StringTest do
  use ExUnit.Case, async: true

  @test_cases [
    [
      "this that",
      [
        "This That",
        "THIS THAT",
        "this that",
        "this that",
        "this  that",
        " this  that  "
      ]
    ],
    [
      "bela bartok",
      ["Béla Bartók"]
    ],
    [
      "bjork",
      ["Björk", "Bjork"]
    ],
    [
      "john and paul",
      ["john & paul", "john &amp; paul", "john &amp paul"]
    ],
    [
      "john paul",
      [
        "john. paul",
        "john, paul",
        "john! paul!",
        "john - paul!",
        "john - [paul!]",
        "john {paul}",
        "john (paul)",
        "john paul...",
        "john paul…"
      ]
    ],
    [
      "count to 10",
      ["Count to 10"]
    ],
    [
      "wiener philharmoniker franz lehar",
      ["Wiener Philharmoniker/Franz Lehár"]
    ]
  ]

  @performer_test_cases Enum.concat(@test_cases, [
                          [
                            "beatles",
                            ["the beatles", "The Beatles", " The  Beatles"]
                          ]
                        ])

  Enum.each(@test_cases, fn [expected, cases] ->
    Enum.each(Enum.with_index(cases), fn {test, n} ->
      test "'#{expected}' #{n}" do
        assert Peel.String.normalize(unquote(test)) == unquote(expected)
      end
    end)
  end)

  Enum.each(@performer_test_cases, fn [expected, cases] ->
    Enum.each(Enum.with_index(cases), fn {test, n} ->
      test "Performer '#{expected}' #{n}" do
        assert Peel.String.normalize_performer(unquote(test)) == unquote(expected)
      end
    end)
  end)
end
