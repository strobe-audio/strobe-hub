defmodule HLS.Stream do
  @moduledoc """
  A stream is defined by a set of URLs for differing bandwidth streams
  """

  alias HLS.Stream
  alias M3.Playlist

  defstruct [
    playlist: nil,
    reader: nil,
  ]

  def new(playlist, reader \\ %HLS.Reader.Http{})
  def new(playlist, reader) do
    %Stream{playlist: playlist, reader: reader}
  end

  def resolve(stream, opts \\ [bandwidth: :highest])
  def resolve(%Stream{playlist: playlist, reader: reader} = stream, [bandwidth: bandwidth] = opts) do
    case playlist do
      %M3.Playlist.Live{} ->
        playlist

      _ ->
        variant = apply(__MODULE__, bandwidth, [stream])
        m3 = HLS.Reader.read!(reader, variant.url)
        resolved = M3.Parser.parse!(m3, variant.url)
        %Stream{stream | playlist: resolved} |> resolve(opts)
    end
  end

  def highest(%Stream{playlist: playlist}) do
    playlist |> Playlist.sort |> List.last
  end

  def lowest(%Stream{playlist: playlist}) do
    playlist |> Playlist.sort |> List.first
  end

  @doc """
  Returns a new variant with a higher data rate or the current stream if no
  higher rate one exists.
  """
  def upgrade(%Stream{playlist: playlist} = stream, %M3.Variant{bandwidth: bandwidth}) do
    high = highest(stream)
    playlist
    |> Playlist.sort
    |> Enum.find(high, fn(%M3.Variant{bandwidth: b}) ->
      b > bandwidth
    end)
  end

  @doc """
  Returns a new variant with a lower data rate or the current stream if no
  lower rate one exists.
  """
  def downgrade(%Stream{playlist: playlist} = stream, %M3.Variant{bandwidth: bandwidth}) do
    low = lowest(stream)
    playlist
    |> Playlist.sort
    |> Enum.reverse
    |> Enum.find(low, fn(%M3.Variant{bandwidth: b}) ->
      b < bandwidth
    end)
  end
end
