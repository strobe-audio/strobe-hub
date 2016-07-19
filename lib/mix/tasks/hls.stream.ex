defmodule Mix.Tasks.Hls.Stream do
  use Mix.Task

  def run(_channel) do
    # Mix.Tasks.App.Start.run([])
    # reader = %HLS.Reader.Http{}
    # path = Path.join([__DIR__, "../../playlists/#{channel}.m3u8"]) |> Path.expand
    # file = File.read!(path)
    # playlist = M3.Parser.parse!(file, "http://www.bbc.co.uk")
    # hls = HLS.Stream.new(playlist, reader)
    # IO.inspect hls
    # stream = HLS.Stream.open!(hls)
    # Enum.each stream, fn(data) ->
    #   IO.binwrite :stdout, data
    # end
  end
end
