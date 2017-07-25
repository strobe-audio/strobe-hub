defmodule Peel.Scanner do
  require Logger

  def start(path) do
    collection = collection_from_path(path)
    path
    |> stream
    |> Enum.each(&scan(collection, &1))
    |> scan_complete
  end

  def stream(path) do
    path
    |> List.wrap
    |> Peel.DirWalker.stream
    |> Stream.filter(&Peel.Importer.is_audio?/1)
  end

  def scan(collection, path) do
    Peel.Importer.track(collection, path)
    path
  end

  def scan_complete(path) do
    Strobe.Events.notify(:peel, :scan_finished, [path])
  end

  defp collection_from_path(path) do
    case Peel.Collection.from_path(path) do
      {:ok, collection, _} ->
        collection
      _err ->
        name = Path.basename(path)
        root = Path.dirname(path)
        Peel.Collection.create(name, root)
    end
  end
end
