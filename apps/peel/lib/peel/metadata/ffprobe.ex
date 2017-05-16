defmodule Peel.Importer.Ffprobe do
  @moduledoc """
  Uses ffprobe to read audio file metadata.
  """

  @args ~w(-show_format -show_streams -print_format json -v quiet)

  def read!(path) do
    {:ok, metadata} = read(path)
    metadata
  end

  def read(path) do
    with {:ok, data} <- read_metadata(path),
      {:ok, format} <- Map.fetch(data, "format"),
      {:ok, streams} <- Map.fetch(data, "streams"),
      {:ok, stream} <- audio_stream(streams),
      {:ok, tags} <- Map.fetch(format, "tags")
    do
      {:ok, %Peel.Metadata{
        bit_rate: to_int(format["bit_rate"]),
        channels: stream["channels"],
        duration_ms: round(String.to_float(stream["duration"]) * 1000),
        extension: extension(path),
        filename: Path.basename(path),
        sample_rate: to_int(stream["sample_rate"]),
        album: tags["album"],
        composer: tags["composer"] || tags["artist"],
        date: tags["date"],
        # disk_number: number(tags[""]),
        # disk_total: total(tags[""]),
        genre: tags["genre"],
        performer: tags["artist"],
        title: tags["title"],
        track_number: number(tags["track"]),
        # track_total: total(tags[""]),
      }}
    else
      err -> err
    end
  end

  def read_metadata(path) do
    case cmd(path) do
      {json, 0} ->
        parse(json)
      err ->
        {:error, "Unable to extract metdata from #{path}: #{inspect err}"}
    end
  end

  def parse(json) do
    Poison.decode(json)
  end

  def cmd(path) do
    executable() |> System.cmd(args(path))
  end

  def args(path) do
    @args ++ [path]
  end

  def executable do
    System.find_executable("ffprobe")
  end

  @doc """
  Returns a file extension without a leading "."

    iex> Peel.Importer.Ffprobe.extension("/some/file.mp3")
    "mp3"
    iex> Peel.Importer.Ffprobe.extension("/some/file")
    ""

  """
  def extension(path) do
    case Path.extname(path) do
      << ".", ext::binary >> -> ext
      ext -> ext
    end
  end

  @doc """
  Converts number/total to number

    iex> Peel.Importer.Ffprobe.number("3/12")
    3
    iex> Peel.Importer.Ffprobe.number("3")
    3
    iex> Peel.Importer.Ffprobe.number(3)
    3
    iex> Peel.Importer.Ffprobe.number(nil)
    nil

  """
  def number(nil), do: nil
  def number(n) when is_integer(n), do: n
  def number(s) when is_binary(s) do
    s |> String.split("/") |> number
  end
  def number([n, _total]), do: n |> to_int
  def number([n]), do: n |> to_int

  @doc """
  Converts number/total to total

    iex> Peel.Importer.Ffprobe.total("3/12")
    12
    iex> Peel.Importer.Ffprobe.total("3")
    nil
    iex> Peel.Importer.Ffprobe.total(nil)
    nil

  """
  def total(nil), do: nil
  def total(s) when is_binary(s) do
    s |> String.split("/") |> total
  end
  def total([_, total]), do: total |> to_int
  def total([_]), do: nil

  defp to_int(s) when is_binary(s), do: String.to_integer(s)
  defp to_int(n) when is_integer(n), do: n
  defp to_int(_), do: nil

  defp audio_stream(streams) do
    case Enum.find(streams, fn(s) -> s["codec_type"] == "audio" end) do
      nil    -> {:error, "No audio stream"}
      stream -> {:ok, stream}
    end
  end
end
