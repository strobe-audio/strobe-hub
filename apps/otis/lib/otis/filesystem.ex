defmodule Otis.Filesystem do
  @moduledoc """
  Various utility functions for converting files & directories into
  music source objects
  """

  import Enum, only: [map: 2, filter: 2]

  defmacro ifexists?(path, do: expression) do
    quote do
      case File.exists?(unquote(path)) do
        true -> unquote(expression)
        false -> {:error, :file_doesnt_exist}
      end
    end
  end

  def file(path) do
    ifexists?(path) do
      Otis.Source.File.new(path)
    end
  end

  def directory(path) do
    ifexists?(path) do
      case directory_listing(path) do
        {:ok, paths} -> {:ok, sources(paths)}
        _ = err -> err
      end
    end
  end

  defp directory_listing(path) do
    case File.ls(path) do
      {:error, _} = err ->
        err

      {:ok, files} ->
        {:ok, files |> Enum.sort() |> map(&Path.join(path, &1))}
    end
  end

  defp sources(paths) do
    paths |> map(&file/1) |> validate_sources
  end

  defp validate_sources(sources) do
    sources |> filter(&reject_errors/1) |> map(&Kernel.elem(&1, 1))
  end

  defp reject_errors({:ok, _}), do: true
  defp reject_errors(_), do: false
end
