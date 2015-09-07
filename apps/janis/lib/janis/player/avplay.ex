defmodule Janis.Player.Avplay do
  use Janis.Player

  def binary, do: "/usr/local/bin/avplay"

  def params do
    [ "-f", "s16le",
      "-ar", "44100",
      "-ac", "2",
      "-nodisp",
      "-loglevel", "quiet",
      "-nostats",
      "-vn",
      "-"
    ]
  end
end

