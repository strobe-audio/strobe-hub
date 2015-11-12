defmodule Otis.Source.Metadata do
  defstruct [
    :album,
    :bit_rate,
    :channels,
    :composer,
    :date,
    :disk_number,
    :disk_total,
    :duration_ms,
    :extension,
    :filename,
    :genre,
    :mime_type,
    :performer,
    :sample_rate,
    :stream_size,
    :title,
    :track_number,
    :track_total
  ]
end
