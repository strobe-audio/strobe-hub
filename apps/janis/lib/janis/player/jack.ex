defmodule Janis.Player.Jack do
  use Janis.Player

  def binary, do: "/usr/bin/jack-stdin"

  def params do
    [ "--quiet", "--prebuffer", "50", "--duration", "0.1", "--bufsize", "1024", "system:playback_1", "system:playback_2" ]
  end
end

