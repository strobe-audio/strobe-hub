defmodule Plug.WebDav.Handler.Put do
  import Plug.Conn

  def call(conn, path, opts) do
    if File.dir?(path) do
      {:error, 405, "Method Not Allowed", conn}
    else
      put(valid?(path), conn, path, opts)
    end
  end

  defp put(true, conn, path, opts) do
    case File.open(path, [:binary, :write, :raw]) do
      {:ok, file} ->
        write(conn, file, read(conn), path, opts)
      {:error, reason} ->
        {:error, 500, to_string(reason), conn}
    end
  end
  defp put(false, conn, _path, _opts) do
        IO.inspect [:put, :conflict, _path]
    {:error, 409, "Conflict", conn}
  end

  defp write(_conn, file, {:ok, data, conn}, _path, _opts) do
    :file.write(file, data)
    File.close(file)
    {:ok, "", conn}
  end
  defp write(_conn, file, {:more, data, conn}, path, opts) do
    case :file.write(file, data) do
      :ok ->
        write(conn, file, read(conn), path, opts)
      {:error, :enospc} ->
        IO.inspect [:put, :error, "NO SPACE"]
        File.close(file)
        {:error, 507, "Insufficient Storage", conn}
      {:error, reason} ->
        IO.inspect [:put, :error, reason]
        File.close(file)
        {:error, 500, to_string(reason), conn}
    end
  end
  defp write(conn, file, {:error, reason}, _path, _opts) do
    File.close(file)
    IO.inspect [:put, :error, reason]
    {:error, 500, to_string(reason), conn}
  end

  defp valid?(path) do
    path |> Path.dirname |> File.dir?
  end

  defp read(conn) do
    read_body(conn, [length: 1_000_000, read_length: 64_000])
  end
end
