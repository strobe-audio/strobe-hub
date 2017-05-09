defmodule Peel.Importer do
  alias Peel.Track
  alias Peel.Repo
  def track(path) do
    {:ok, result} = Repo.transaction fn ->
      path |> Track.by_path |> _track(path)
    end
    result
  end

  defp _track(nil, path) do
    create_track(path, metadata(path))
  end
  defp _track(%Track{} = track, _path) do
    {:existing, track}
  end

  defp create_track(path, metadata) do
    track =
      path
      |> Track.new(metadata)
      |> Track.create!
    {:created, track}
  end

  def metadata(path) do
    path |> Peel.File.metadata! |> clean_metadata
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

  def filetype_filter(path) do
    path |> Path.extname |> is_accepted_format
  end

  def is_accepted_format(".mp3"), do: true
  def is_accepted_format(".m4a"), do: true
  def is_accepted_format(".flac"), do: true
  def is_accepted_format(".ogg"), do: true
  def is_accepted_format(_), do: false
end
