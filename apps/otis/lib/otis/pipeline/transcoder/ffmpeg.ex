defmodule Otis.Pipeline.Transcoder.Ffmpeg do
  @moduledoc """
  Provides a convenient way to transcode any music input stream
  into PCM in the approved format using ffmpeg
  """

  @doc """
  Takes an input stream and an argument list describing the input stream format
  and returns an PCM output stream
  """
  def transcode(inputstream, input_args, offset_ms, config) do
    opts = [out: :stream, in: inputstream]
    proc = %{out: outstream} = ExternalProcess.spawn(executable(), params(input_args, offset_ms, config), opts)
    {proc, outstream}
  end

  defp params(input_args, offset_ms, config) do
    Enum.concat(input_args, ["-i", "-", "-ss", ms_to_s(offset_ms) | params(config)])
  end

  defp params(config) do
    [ "-f", "s16le",
      "-ar", Integer.to_string(config.sample_freq),
      "-ac", Integer.to_string(config.channels),
      "-"
    ]
  end

  defp ms_to_s(ms) do
    to_string(ms / 1000.0)
  end

  def executable do
    System.find_executable("ffmpeg")
  end
end
