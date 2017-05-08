defmodule HLS do
  def now do
    DateTime.utc_now |> DateTime.to_unix(:millisecond)
  end

  def whitenoise_path, do: Path.join([:code.priv_dir(:otis_library_bbc), "audio/white.ts"])
  def whitenoise, do: File.read!(whitenoise_path())
  def whitenoise_url, do: "file://#{whitenoise_path()}"

  def read_with_timeout(reader, url, timeout) do
    task = Task.async(fn -> read_handling_errors(reader, url) end)
    Task.yield(task, timeout) || (fn() -> IO.inspect [:shutdown] ; Task.shutdown(task) end).()
  end

  def read_handling_errors(reader, url) do
    try do
      HLS.Reader.read(reader, url)
    rescue e ->
      {:error, e}
    catch e, r ->
      {:error, {e, r}}
    end
  end
end
