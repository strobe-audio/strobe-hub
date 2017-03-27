defmodule HLS do
  def now do
    DateTime.utc_now |> DateTime.to_unix(:millisecond)
  end

  @whitenoise_path Path.join([__DIR__, "hls/white.ts"])

  def whitenoise, do: File.read!(@whitenoise_path)
  def whitenoise_url, do: "file://#{@whitenoise_path}"
  def whitenoise_path, do: @whitenoise_path
end
