defmodule Otis.MP3 do
  def decode_file(path) do

    case File.read(path) do
      {:ok, binary} ->
        decode_id3(binary)
      _ ->
        IO.puts "Couln't open file #{path}"
    end
  end

  def decode_id3(mp3_binary) do
    mp3_byte_size = (byte_size(mp3_binary) - 128)
    << _ :: binary-size(mp3_byte_size), id3_tag :: binary >> = mp3_binary
    IO.inspect id3_tag
    << "TAG",
    title   :: binary-size(30),
    artist  :: binary-size(30),
    album   :: binary-size(30),
    year    :: binary-size(4),
    comment :: binary-size(30),
    _rest   :: binary >> = id3_tag

    IO.puts title |> strip_null
    IO.puts artist |> strip_null
    IO.puts album |> strip_null
    IO.puts year
    IO.puts comment |> strip_null

    {:ok, nil}
  end

  defp strip_null(binary) do
    case :binary.match(binary, <<0x0>>) do
      {pos, _} ->
        << value :: binary-size(pos), _ :: binary >> = binary
        value
      _ ->
        binary
    end
  end
end
