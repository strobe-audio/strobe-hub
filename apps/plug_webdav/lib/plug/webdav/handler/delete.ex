defmodule Plug.WebDAV.Handler.Delete do

  def call(conn, path, opts) do
    delete(conn, path, stat(path), opts)
  end

  def delete(conn, _path, {false, _}, _opts) do
    {:error, 404, "Not Found", conn}
  end

  def delete(conn, path, {true, true}, _opts) do
    case File.rm_rf(path) do
      {:ok, _files} ->
        {:ok, conn}
      {:error, reason, file} ->
        {:error, 500, "#{file} => #{reason}", conn}
    end
  end
  def delete(conn, path, {true, false}, _opts) do
    case File.rm(path) do
      :ok ->
        {:ok, conn}
      {:error, reason} ->
        {:error, 500, to_string(reason), conn}
    end
  end

  defp stat(path) do
    {File.exists?(path), File.dir?(path)}
  end
end
