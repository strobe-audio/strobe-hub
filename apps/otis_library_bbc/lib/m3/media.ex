defmodule M3.Media do
  defstruct url: nil, duration: 0, filename: ""

  def read_timeout(%M3.Media{duration: duration}) do
    round(duration * 1000)
  end
end
