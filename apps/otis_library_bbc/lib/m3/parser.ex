defmodule M3.Parser do
  alias __MODULE__
  alias M3.Media

  defstruct [
    uri: "",
    type: %M3.Playlist{},
    metadata: %{},
    media: [],
    extinf: {0, ""},
    streaminf: nil,
    version: nil,
  ]

  def parse!(body, uri) when is_binary(uri) do
    parse!(body, URI.parse(uri))
  end

  def parse!(body, %URI{} = uri) do
    body |> split_lines |> parse_lines(%Parser{uri: uri})
  end

  defp split_lines(body) do
    body |> String.split("\n") |> Enum.map(&String.trim/1)
  end

  defp parse_lines([], parser) do
    struct(parser.type, %{
      version: parser.version,
      uri: parser.uri,
      media: Enum.reverse(parser.media),
      metadata: parser.metadata
    })
  end

  defp parse_lines([line | lines], parser) do
    parser = parse_line(line, parser)
    parse_lines(lines, parser)
  end
  defp parse_line("#EXTM3U" <> _line, parser) do
    parser
  end
  defp parse_line("#EXT-X-VERSION:" <> version, parser) do
    parser |> set_version(String.to_integer(version))
  end
  defp parse_line("#EXT-X-TARGETDURATION:" <> duration, parser) do
    parser |> set_target_duration(String.to_integer(duration))
  end
  defp parse_line("#EXT-X-MEDIA-SEQUENCE:" <> seq, parser) do
    parser |> set_media_sequence(seq)
  end
  defp parse_line("#EXT-X-STREAM-INF:" <> comment, parser) do
    metadata = comment |> parse_metadata
    parser |> set_stream_inf(metadata)
  end
  defp parse_line("#EXTINF:" <> media_info, parser) do
    if match = Regex.run(~r/(\d+)\s*,\s*(.+)$/, media_info) do
      [_, duration, filename] = match
      parser |> set_extinf(duration, filename)
    else
      parser
    end
  end
  defp parse_line("#" <> _, parser) do
    parser
  end
  defp parse_line("", parser) do
    parser
  end
  defp parse_line(url, %Parser{streaminf: %{}} = parser) do
    uri = URI.merge(parser.uri, url)
    variant = struct(M3.Variant, Map.merge(parser.streaminf, %{url: to_string(uri)}))
    parser |> append_media(variant) |> reset_streaminf()
  end
  defp parse_line(url, parser) do
    uri = URI.merge(parser.uri, url)
    {duration, filename} = parser.extinf
    parser |> append_media(%Media{url: to_string(uri), duration: duration, filename: filename}) |> reset_extinf()
  end

  defp parse_metadata(metadata) when is_binary(metadata) do
    metadata |> String.split(",") |> parse_metadata(%{})
  end

  defp parse_metadata([], acc) do
    acc
  end
  defp parse_metadata([setting | metadata], acc) do
    [key, value] = String.split(setting, "=")
    acc = Map.put(acc, key, metadata_value(value))
    parse_metadata(metadata, acc)
  end

  defp metadata_value(value) do
    if match = Regex.run(~r/^"([^"]*)"$/, value) do
      [_, unquoted] = match
      unquoted
    else
      value
    end
  end

  defp set_extinf(parser, duration, filename) when is_binary(duration) do
    set_extinf(parser, String.to_integer(duration), filename)
  end
  defp set_extinf(parser, duration, filename) do
    %Parser{parser | extinf: {duration, filename}}
  end

  defp set_stream_inf(parser, %{bandwidth: _bandwidth, codecs: _codecs, program_id: _program_id} = stream_inf) do
    %Parser{parser | type: %M3.Playlist.Variant{}, streaminf: stream_inf}
  end
  defp set_stream_inf(parser, %{"BANDWIDTH" => bandwidth, "CODECS" => codecs, "PROGRAM-ID" => program_id}) do
    set_stream_inf(parser, %{bandwidth: String.to_integer(bandwidth), codecs: parse_codecs(String.split(codecs, ",")), program_id: program_id})
  end

  defp parse_codecs(codecs) do
    codecs
    |> Enum.map(&String.split(&1, "."))
    |> Enum.map(fn([type | versions]) -> [type, Enum.join(versions, ".")] end)
  end

  defp set_target_duration(parser, duration) do
    type = case parser.type do
      %M3.Playlist.Live{} ->
        %M3.Playlist.Live{parser.type | target_duration: duration}
      _ ->
        %M3.Playlist.Live{target_duration: duration}
    end
    %Parser{parser | type: type}
  end
  defp set_media_sequence(parser, seq) do
    type = case parser.type do
      %M3.Playlist.Live{} ->
        %M3.Playlist.Live{parser.type | media_sequence_number: String.to_integer(seq)}
      _ ->
        %M3.Playlist.Live{media_sequence_number: String.to_integer(seq)}
    end
    %Parser{parser | type: type}
  end

  defp set_version(parser, version) do
    %Parser{parser | version: version}
  end
  defp reset_extinf(parser) do
    %Parser{parser | extinf: {0, ""}}
  end

  defp reset_streaminf(parser) do
    %Parser{parser | streaminf: nil}
  end

  defp append_media(parser, media) do
    %Parser{parser | media: [media | parser.media]}
  end
end
