defmodule Otis.Library.UPNP.Media do
    defstruct [
      :uri,
      :size,
      :duration,
      :bitrate,
      :sample_freq,
      :channels,
      :info,
    ]
    def duration_string(media) do
      media |> duration_ms() |> Otis.Library.Duration.hms_ms()
    end

    def duration_ms(%__MODULE__{duration: duration}) do
      duration
    end
end
