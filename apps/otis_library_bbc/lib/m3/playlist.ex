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

  def sequence(%M3.Playlist.Live{} = new_playlist, %M3.Playlist.Live{} = old_playlist) do
    %M3.Playlist.Live{media_sequence_number: new_msn, media: new_media} = new_playlist
    %M3.Playlist.Live{media_sequence_number: old_msn} = old_playlist
    _sequence(new_msn, new_media, old_msn)
  end
  def sequence(new_playlist, _old_playlist) do
    {:ok, new_playlist.media}
  end

  def read_timeout(%M3.Playlist.Live{target_duration: target_duration}) do
    round(target_duration * 1000)
  end

  defp _sequence(new_msn, _new_media, old_msn) when new_msn < old_msn do
    {:ok, []}
  end
  defp _sequence(new_msn, new_media, old_msn) do
    gap = new_msn - old_msn
    media = Enum.drop(new_media, length(new_media) - gap)
    {:ok, media}
  end
end
