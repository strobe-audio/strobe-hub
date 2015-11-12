defmodule Otis.Filesystem.File do
  @moduledoc """
  Represents an audio file on-disk
  """

  defstruct [
    :path,
    :metadata
  ]

  alias Otis.Source.Metadata, as: M

  def new(path) do
    path |> Path.expand |> read
  end

  defp read(path) do
    case read_metadata(path) do
      {xml, 0} -> parse_metadata(xml, path)
      {_,   n} -> {:error, :status, n}
    end
  end

  defp parse_metadata(xml, path) do
    state = %{ field: nil, data: %M{}, audio_track: false }
    {:ok, result, _} = :erlsom.parse_sax(xml, state, &sax_event/2)
    file = %__MODULE__{path: path, metadata: result.data}
    {:ok, file}
  end

  Enum.each [
    :album, :composer, :date, :extension, :filename, :genre, :mime_type,
    :performer, :title
  ], fn(field) ->
    defp sax_event({:characters, cdata}, %{field: unquote(field), data: data} = state) do
      %{ state | data: :maps.put(unquote(field), to_string(cdata), data) }
    end
  end

  @integer ~r(^\d+$)

  # Parse the numeric audio metadata
  Enum.each [
    [:bit_rate,     true ], [:channels,     true ], [:disk_number,  false],
    [:disk_total,   false], [:duration_ms,  true ], [:sample_rate,  true ],
    [:stream_size,  true ], [:track_number, false], [:track_total,  false]
  ], fn([field, audio]) ->
    defp sax_event({:characters, cdata}, %{audio_track: unquote(audio), field: unquote(field), data: data} = state) do
      case Regex.match?(@integer, to_string(cdata)) do
        true  -> %{ state | data: :maps.put(unquote(field), List.to_integer(cdata, 10), data) }
        false -> state
      end
    end
  end

  defp sax_event({:characters, _}, state) do
    state
  end

  Enum.each [
    ['Album',               :album       ], ['Bit_rate',            :bit_rate    ],
    ['Channel_s_',          :channels    ], ['Composer',            :composer    ],
    ['Duration',            :duration_ms ], ['File_extension',      :extension   ],
    ['File_name',           :filename    ], ['Genre',               :genre       ],
    ['Internet_media_type', :mime_type   ], ['Part_Position',       :disk_number ],
    ['Part_Total',          :disk_total  ], ['Performer',           :performer   ],
    ['Recorded_date',       :date        ], ['Sampling_rate',       :sample_rate ],
    ['Stream_size',         :stream_size ], ['Title',               :title       ],
    ['Track_name_Position', :track_number], ['Track_name_Total',    :track_total ]
  ], fn([tag, field]) ->
    defp sax_event({:startElement, [], unquote(tag), [], []}, state) do
      %{ state | field: unquote(field) }
    end
  end

  defp sax_event({:startElement, [], 'track', [], [{:attribute, 'type', [], [], 'Audio'} | _attrs]}, state) do
    %{ state | audio_track: true }
  end

  defp sax_event({:startElement, [], 'track', [], [{:attribute, 'type', [], [], _type} | _attrs]}, state) do
    state
  end

  defp sax_event({:endElement, [], _tag, []}, state) do
    %{state | field: nil }
  end

  defp sax_event(_event, state) do
    state
  end

  defp read_metadata(path) do
    System.cmd mediainfo, args(path), parallelism: true
  end

  defp args(path) do
    ["--Full", "--Output=XML", path]
  end

  defp mediainfo do
    System.find_executable("mediainfo")
  end
end
