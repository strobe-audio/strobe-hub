defmodule Otis.Sox do
  @moduledoc """
  Provides a convenient way to transcode any music input stream
  into PCM in the approved format.
  """


  @sox_binary "/usr/local/bin/sox"

  @doc """
  Takes an input stream of the given format type and returns
  an PCM output stream
  """
  def transcode(inputstream, type) do
    opts = [out: :stream, in: inputstream]
    _proc = %Porcelain.Process{pid: pid, out: outstream } = Porcelain.spawn(@sox_binary, sox_params(type), opts)
    {pid, outstream}
  end

  defp sox_params(input_type) do
    ["--type", input_type, "-" | sox_params]
  end

  defp sox_params do
    [ "--channels", Integer.to_string(Otis.sample_channels),
      "--bits", Integer.to_string(Otis.sample_bits),
      "--rate", Integer.to_string(Otis.sample_freq),
      "--type", "raw",
      "--encoding", "signed-integer",
      "--endian", "little",
      "-" ]
  end
end
