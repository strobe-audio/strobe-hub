defmodule Peel.CoverArt.Importer do
  use     GenServer
  require Logger

  @name Peel.CoverArt.Importer
  @max_workers 2

  def start do
    GenServer.cast(@name, :start)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    Otis.State.Events.add_mon_handler(Peel.CoverArt.EventHandler, {})
    {:ok, {}}
  end

  def handle_cast(:start, state) do
    {:ok, _pid} = Task.start(&rescan_library/0)
    {:noreply, state}
  end

  defp rescan_library do
    Peel.CoverArt.pending_albums |> import_albums
  end

  defp import_albums([]) do
    Logger.info "No albums without cover art found"
  end

  defp import_albums(albums) do
    workers = 4
    Logger.info "Launching cover art scan with #{workers} workers"
    opts = [
      worker_count: workers,
      report_progress_to: &progress/1,
      report_progress_interval: 250,
    ]
    WorkQueue.process(&extract_cover_image/2, albums, opts)
  end

  def extract_cover_image(album, _) do
    Logger.info "Extracting cover of #{ album.performer } > #{ album.title }"
    Peel.CoverArt.extract_and_assign(album)
  end

  def progress({:started, nil}) do
    Otis.State.Events.notify({:cover_art_extraction, :start})
  end
  def progress({:finished, _results}) do
    Otis.State.Events.notify({:cover_art_extraction, :finish})
  end
  def progress({:progress, count}) do
    Otis.State.Events.notify({:cover_art_extraction, :progress, count})
  end
end
