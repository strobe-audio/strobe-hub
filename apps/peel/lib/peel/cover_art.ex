defmodule Peel.CoverArt do
  use    GenServer

  alias Peel.Album

  require Logger

  @name Peel.CoverArt
  @placeholder_image "/peel/placeholder.jpg"


  def pending_albums do
    Album.without_cover_image()
  end

  def extract_and_assign(album) do
    result = {:ok, cover_image} = album_art(album)
    update_album(album, cover_image)
    result
  end

  def album_art(album) do
    case Album.tracks(album) do
      [track | _] -> album_art(album, track.path)
      [] -> {:ok, @placeholder_image}
    end
  end

  def album_art(%Album{cover_image: nil} = album, track_path) do
    # This path should come from the global peep media config
    # and should be a URL suitable for use in the client
    filename = "#{album.id}.jpg"
    {:ok, path, url} = Otis.Media.location([Peel.library_id, "cover"], filename, optimize: 2)
    case extract(track_path, path) do
      :ok ->
        {:ok, url}
      :error ->
        {:ok, @placeholder_image}
    end
  end

  def album_art(album, _track_path) do
    {:ok, album.cover_image}
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def update_album(album, artwork_path) do
    GenServer.cast(@name, {:update, album, artwork_path})
  end

  def init([]) do
    {:ok, %{}}
  end


  def handle_cast({:update, album, image_path}, state) do
    Logger.info "Cover for #{ album.performer } > #{ album.title } ==> #{ image_path }"
    Peel.Repo.transaction fn ->
      Album.set_cover_image(album, image_path)
    end
    {:noreply, state}
  end


  def extract(input_path, output_path) do
    case System.cmd(executable, ["-v", "quiet", "-i", input_path, output_path]) do
      {_, 0} -> :ok
      {_, _} -> :error
    end
  end

  defp executable do
    System.find_executable("avconv")
  end
end
