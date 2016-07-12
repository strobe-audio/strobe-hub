defmodule HLS.BBC do
  def radio4 do
    stream("radio4")
  end

  defp stream(channel) do
    reader = %HLS.Reader.Http{}
    channel |> playlist |> HLS.Stream.new(reader)
  end

  defp playlist(channel) do
    path = Path.join([__DIR__, "bbc/#{channel}.m3u8"]) |> Path.expand
    file = File.read!(path)
    playlist = M3.Parser.parse!(file, "http://www.bbc.co.uk")
  end
end
