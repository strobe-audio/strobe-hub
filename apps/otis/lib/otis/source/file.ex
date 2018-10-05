defmodule Otis.Source.File do
  @moduledoc """
  Represents an audio file on-disk
  """

  @derive {Poison.Encoder, only: [:id, :metadata]}
  defstruct [:id, :path, :metadata]

  @type t :: %__MODULE__{}

  @doc """
  Returns a new file-with-metadata struct raising an exception if there's a problem
  """
  @spec new!(binary) :: t
  def new!(path) do
    {:ok, file} = new(path)
    file
  end

  def new(path) do
    path |> Path.expand |> validate
  end

  def extension(%__MODULE__{path: path}) do
    Path.extname(path)
  end

  defp validate(path) do
    if File.exists?(path) do
      {:ok, %__MODULE__{id: path, path: path}}
    else
      {:error, :enoent}
    end
  end
end

defimpl Otis.Library.Source, for: Otis.Source.File do
  alias Otis.Source.File

  def id(file) do
    file.id
  end

  def type(_file) do
    Otis.Source.File
  end

  def open!(%File{path: path}, _id, packet_size_bytes) do
    Elixir.File.stream!(path, [], packet_size_bytes)
  end

  def pause(_file, _id, _stream) do
    :ok # no-op
  end

  def close(_file, _id, stream) do
    Elixir.File.close(stream)
  end

  def transcoder_args(%File{path: path}) do
    ["-f", path |> Path.extname |> Otis.Library.strip_leading_dot]
  end

  def metadata(_file) do
    %{}
  end

  def duration(%File{metadata: metadata}) do
    {:ok, metadata.duration_ms}
  end

  def activate(_track, _channel_id) do
    :ok
  end

  def deactivate(_track, _channel_id) do
    :ok
  end
end

defimpl Otis.Library.Source.Origin, for: Otis.Source.File do
  alias Otis.Source.File

  def load!(%File{id: id}) do
    Otis.Source.File.Cache.lookup(id, fn ->
      File.new!(id)
    end)
  end
end
