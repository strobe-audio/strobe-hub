defmodule Peel.CoverArt.EventHandler do
  use GenEvent

  def handle_event({:scan_finished, [_path]}, state) do
    Peel.CoverArt.Importer.start()
    {:ok, state}
  end

  def handle_event({:otis_started, []}, state) do
    Peel.CoverArt.Importer.start()
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end
