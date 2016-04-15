defmodule Otis.State do
  require Logger

  defmodule ZoneStatus do
    @derive {Poison.Encoder, only: [:id, :name, :volume, :position, :playing]}

    defstruct [:id, :name, :volume, :position, :playing]
  end

  defmodule ReceiverStatus do
    defstruct [:id, :name, :volume, :online, :zone_id, :online]
  end

  defmodule SourceStatus do
    defstruct [:id, :position, :source, :playback_position, :source_id, :zone_id]
  end

  @doc "Returns the current state from the db"
  def current do
    zones = [ active_zone | _ ] = zones()
    %{ zones: zones, receivers: receivers(), sources: sources(), activeZoneId: active_zone.id }
  end

  defp zones do
    # TODO:
    # - playlist
    # - current song
    Enum.map Otis.State.Zone.all, &status/1
  end

  def receivers do
    # TODO: find live state
    Enum.map Otis.State.Receiver.all, &status/1
  end

  def sources do
    Enum.map Otis.State.Source.all, &source/1
  end

  def status(%Otis.State.Zone{} = zone) do
    status = zone |> Map.from_struct |> Map.merge(zone_status(zone))
    struct(ZoneStatus, status)
  end

  def status(%Otis.State.Receiver{} = receiver) do
    status = receiver |> Map.from_struct |> Map.merge(receiver_status(receiver))
    struct(ReceiverStatus, status)
  end

  def source(source) do
    status = source |> Map.from_struct |> Map.merge(source_status(source))
    struct(SourceStatus, status)
  end

  def receiver_status(receiver) do
    %{online: Otis.Receivers.connected?(receiver.id)}
  end

  def zone_status(zone) do
    %{playing: Otis.Zones.playing?(zone.id)}
  end

  # TODO: I need a separate nonclameture for the entry in a source list as
  # opposed to the actual source it refers to
  def source_status(entry) do
    source = Otis.State.Source.source(entry)
    %{source: source}
  end
end

defimpl Poison.Encoder, for: Otis.State.ReceiverStatus do
  def encode(status, opts) do
    status
    |> Map.take([:id, :name, :volume, :online, :online])
    |> Map.put(:zoneId, status.zone_id)
    |> Poison.Encoder.encode(opts)
  end
end

defimpl Poison.Encoder, for: Otis.State.SourceStatus do
  def encode(status, opts) do
    status
    |> Map.take([:id, :position, :source])
    |> Map.put(:playbackPosition, status.playback_position)
    |> Map.put(:sourceId, status.source_id)
    |> Map.put(:zoneId, status.zone_id)
    |> Poison.Encoder.encode(opts)
  end
end
