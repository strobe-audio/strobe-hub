defmodule Otis.State do
  require Logger

  defmodule ZoneStatus do
    @derive {Poison.Encoder, only: [:id, :name, :volume, :position, :playing]}

    defstruct [:id, :name, :volume, :position, :playing]
  end

  defmodule ReceiverStatus do
    defstruct [:id, :name, :volume, :online, :zone_id, :online]
  end

  @doc "Returns the current state from the db"
  def current do
    %{ zones: zones(), receivers: receivers() }
  end

  defp zones do
    # TODO:
    # - status (playing/stopped)
    # - playlist
    # - current song
    Enum.map Otis.State.Zone.all, &status/1
  end

  def receivers do
    # TODO: find live state
    Enum.map Otis.State.Receiver.all, &status/1
  end

  def status(%Otis.State.Zone{} = zone) do
    status = zone |> Map.from_struct |> Map.merge(zone_status(zone))
    struct(ZoneStatus, status)
  end

  def status(%Otis.State.Receiver{} = receiver) do
    status = receiver |> Map.from_struct |> Map.merge(receiver_status(receiver))
    struct(ReceiverStatus, status)
  end

  def receiver_status(receiver) do
    %{
      online: Otis.Receivers.connected?(receiver.id)
    }
  end

  def zone_status(zone) do
    %{
      playing: Otis.Zones.playing?(zone.id)
    }
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
