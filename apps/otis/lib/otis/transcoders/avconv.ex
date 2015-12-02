defmodule Otis.Transcoders.Avconv do
  @moduledoc """
  Provides a convenient way to transcode any music input stream
  into PCM in the approved format.
  """

  @doc """
  Takes an input stream of the given format type and returns
  an PCM output stream
  """
  def transcode(inputstream, type) do
    opts = [out: :stream, in: inputstream]
    _proc = %Porcelain.Process{pid: pid, out: outstream } = Porcelain.spawn(executable, params(type), opts)
    {pid, outstream}
  end

  defp params(input_type) do
    ["-f", strip_leading_dot(input_type), "-i", "-" | params]
  end

  defp params do
    [ "-f", "s16le",
      "-ar", Integer.to_string(Otis.sample_freq),
      "-ac", Integer.to_string(Otis.sample_channels),
      "-" ]
  end

  defp strip_leading_dot(ext) do
    String.lstrip(ext, ?.)
  end

  defp executable do
    System.find_executable("avconv")
  end
end
