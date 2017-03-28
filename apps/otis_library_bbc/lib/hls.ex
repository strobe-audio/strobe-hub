defmodule HLS do
  def now do
    DateTime.utc_now |> DateTime.to_unix(:millisecond)
  end

  @whitenoise_path Path.join([__DIR__, "hls/white.ts"])

  def whitenoise, do: File.read!(@whitenoise_path)
  def whitenoise_url, do: "file://#{@whitenoise_path}"
  def whitenoise_path, do: @whitenoise_path

  def read_with_timeout(reader, url, timeout) do
    task = Task.async(HLS.Reader, :read!, [reader, url])
    Task.yield(task, timeout) || Task.shutdown(task)
  end
end
