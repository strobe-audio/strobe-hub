defmodule Peel.Scanner do
  require Logger

  def start(path) do
    path |> stream |> Enum.each(&scan/1) |> scan_complete
  end

  def stream(path) do
    path
    |> List.wrap
    |> Peel.DirWalker.stream
    |> Stream.filter(&Peel.Importer.is_audio?/1)
  end

  def scan(path) do
    Peel.Importer.track(path)
    path
  end

  if Code.ensure_compiled?(Otis.Events) do
    def scan_complete(path) do
      Otis.Events.notify({:scan_finished, [path]})
    end
  else
    def scan_complete(_path), do: nil
  end
end
