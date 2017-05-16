defmodule Peel.Importer do
  alias Peel.Track
  alias Peel.Repo

  def track(path) do
    track(path, is_audio?(path))
  end

  def track(path, false) do
    {:ignored, :not_audio}
  end
  def track(path, true) do
    path |> Track.by_path |> _track(path)
  end

  defp _track(nil, path) do
    create_track(path)
  end
  defp _track(%Track{}, path) do
    {:ignored, :duplicate}
  end

  def create_track(path) do
    create_track(path, metadata(path))
  end

  def create_track(path, metadata) when is_map(metadata) do
    Repo.transaction fn ->
      path
      |> Track.new(clean_metadata(metadata))
      |> Track.create!
    end
  end
  def create_track(path, {:ok, metadata}) do
    create_track(path, metadata)
  end
  def create_track(_path, err) do
    err
  end

  def metadata(path) do
    Peel.Importer.Ffprobe.read(path)
  end

  defp clean_metadata(nil) do
    nil
  end
  defp clean_metadata(metadata) do
    metadata
    |> Map.from_struct
    # Reject any nil values so that they don't overwrite defaults
    |> Enum.reject(fn({_, v}) -> is_nil(v) end)
    |> Enum.map(&strip_whitespace/1)
    |> Enum.map(&translate_metadata_key/1)
  end

  # We reserve %Track.album to point to the album relation
  defp translate_metadata_key({:album, album}), do: {:album_title, album}
  defp translate_metadata_key(term), do: term

  defp strip_whitespace({key, value}) when is_binary(value) do
    {key, String.trim(value)}
  end
  defp strip_whitespace(term), do: term

  def is_audio?(path) do
    path |> Path.extname |> is_audio_format?
  end

  @audio_exts ~w(.aac .flac .m4a .mp3 .oga .ogg)

  for e <- @audio_exts do
    def is_audio_format?(unquote(e)), do: true
  end
  def is_audio_format?(_), do: false
end
