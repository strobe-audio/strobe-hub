defmodule Peel.CoverArt do
  use    GenServer

  alias Peel.Album
  alias Peel.Track

  require Logger

  @name Peel.CoverArt
  @placeholder_path  Path.expand("./cover_art/placeholder.jpg", __DIR__)

  if Code.ensure_loaded?(Otis.Media) do
    @placeholder_image Otis.Media.copy!(Peel.library_id, "placeholder.jpg", @placeholder_path)
  else
    @placeholder_image "placeholder.jpg"
  end

  def pending_albums do
    Album.without_cover_image()
  end

  def extract_and_assign(album) do
    result = {:ok, cover_image} = extract_album_art(album) |> lookup_album_art(album) |> assign_default_cover(album)
    update_album(album, cover_image)
    result
  end

  def extract_album_art(album) do
    case Album.tracks(album) do
      [track | _] -> extract_album_art(album, track.path)
      [] -> {:error, nil}
    end
  end

  def extract_album_art(%Album{cover_image: cover_image} = album, track_path) when cover_image in [nil, ""] do
    # This path should come from the global peep media config
    # and should be a URL suitable for use in the client
    {:ok, path, url} = media_location(album)
    case extract(track_path, path) do
      :ok -> {:ok, url}
      :error -> {:error, :no_image_metadata}
    end
  end

  def extract_album_art(album, _track_path) do
    {:ok, album.cover_image}
  end

  def lookup_album_art({:ok, image}, _album) do
    {:ok, image}
  end
  def lookup_album_art({:error, _reason}, album) do
    {:ok, path, url} = media_location(album)
    case MusicBrainz.cover_art(album, path) do
      :ok -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  def assign_default_cover({:ok, image}, _album) do
    {:ok, image}
  end
  def assign_default_cover({:error, _reaons}, _album) do
    {:ok, @placeholder_image}
  end

  def media_location(%Album{id: id}), do: media_location(id)
  def media_location(%Track{album_id: album_id}), do: media_location(album_id)
  def media_location(album_id) when is_binary(album_id) do
    Otis.Media.location(media_namespace, "#{album_id}.jpg", optimize: 2)
  end

  def media_namespace do
    [Peel.library_id, "cover"]
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
