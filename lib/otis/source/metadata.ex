defmodule Otis.Source.Metadata do
  defstruct [
    # Technical
    :bit_rate,
    :channels,
    :duration_ms,
    :extension,
    :filename,
    :mime_type,
    :sample_rate,
    :stream_size,
    # Cultural
    :album,
    :composer,
    :date,
    :disk_number,
    :disk_total,
    :genre,
    :performer,
    :title,
    :track_number,
    :track_total
  ]

  @type t :: %__MODULE__{}

  @doc "Returns the audio type as a {extension, mime type} tuple"
  @spec type(t) :: {binary, binary}
  def type(data) do
    {data.extension, data.mime_type}
  end
end
