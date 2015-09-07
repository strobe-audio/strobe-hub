defmodule Janis.Player.Sox do
  use Janis.Player

  @buffer_size 3528*4

  def binary, do: "/usr/local/bin/play"

  # TODO: find a way to share these values between Otis & Janis
  def params do
    [ "--channels", "2",
      "--bits", "16",
      "--rate", "44100",
      "--type", "raw",
      "--encoding", "signed-integer",
      "--endian", "little",
      "--ignore-length",
      "-",
      "--buffer", Integer.to_string(@buffer_size),
      "--no-show-progress"
    ]
  end
end
