defmodule Peel.CoverArt.Importer do
  use     GenServer
  require Logger

  @name Peel.CoverArt.Importer

  def start do
    GenServer.cast(@name, :start)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    {:ok, {}}
  end

  def handle_cast(:start, state) do
    # Make this block this process so that repeat calls to start execute
    # sequentially
    rescan_library()
    {:noreply, state}
  end

  defp rescan_library do
    Peel.CoverArt.pending_albums |> import_albums
    Peel.CoverArt.pending_artists |> import_artists
  end

  defp import_albums([]) do
    Logger.info "No albums without cover art found"
  end

  defp import_albums(albums) do
    workers = 1
    Logger.info "Launching cover art scan with #{workers} workers"
    opts = [
      worker_count: workers,
      report_progress_to: &progress/1,
      report_progress_interval: 250,
    ]
    WorkQueue.process(&extract_cover_image/2, albums, opts)
  end

  defp import_artists([]) do
    Logger.info "No artists without image found"
  end
  defp import_artists(artists) do
    workers = 1
    Logger.info "Launching artist image import with #{workers} workers"
    opts = [
      worker_count: workers,
      # report_progress_to: &progress/1,
      # report_progress_interval: 250,
    ]
    WorkQueue.process(&assign_artist_image/2, artists, opts)
  end

  def extract_cover_image(album, _) do
    Logger.info "Extracting cover of #{ album.performer } > #{ album.title }"
    Peel.CoverArt.extract_and_assign(album)
  end

  def assign_artist_image(artist, _) do
    Logger.info "Looking for artist image #{ artist.name }"
    Peel.CoverArt.artist_image(artist)
  end

  if Code.ensure_compiled?(Otis.Events) do
    def progress({:started, nil}) do
      Otis.Events.notify(:cover_art, :start, [])
    end
    def progress({:finished, _results}) do
      Otis.Events.notify(:cover_art, :finish, [])
    end
    def progress({:progress, count}) do
      Otis.Events.notify(:cover_art, :progress, [count])
    end
  else
    def progress(_evt), do: nil
  end
end
