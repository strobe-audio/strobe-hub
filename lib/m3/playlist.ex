defmodule M3.Playlist do
  defstruct [
    version: 0,
    uri: nil,
    media: [],
  ]

  # TODO: have a way to specify the format/quality you want
  def variant(%M3.Playlist.Variant{media: [variant | _]}) do
    variant
  end

  def sort(%M3.Playlist.Variant{media: media}) do
    Enum.sort_by(media, fn(m) -> m.bandwidth end)
  end
  def sort(playlist) do
    playlist.media
  end
end
