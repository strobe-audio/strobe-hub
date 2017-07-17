defmodule Otis.State do
  require Logger

  defmodule ChannelStatus do
    @derive {Poison.Encoder, only: [:id, :name, :volume, :position, :playing]}

    defstruct [:id, :name, :volume, :position, :playing]
  end

  defmodule ReceiverStatus do
    defstruct [:id, :name, :volume, :online, :channel_id, :online, :muted]
  end

  defmodule RenditionStatus do
    defstruct [:id, :next_id, :source, :playback_position, :source_id, :channel_id, active: false]
  end

  @doc "Returns the current state from the db"
  def current do
    channels = channels()
    %{ channels: channels, receivers: receivers(), renditions: renditions() }
  end

  defp channels do
    # TODO:
    # - playlist
    # - current song
    Enum.map Otis.State.Channel.all(), &status/1
  end

  def receivers do
    # TODO: find live state
    Enum.map Otis.State.Receiver.all(), &status/1
  end

  def renditions do
    Otis.State.Channel.all()
    |> Enum.map(&channel_renditions/1)
    |> Enum.concat()
  end

  defp channel_renditions(channel) do
    with {:ok, pid} = Otis.Channels.find(channel.id),
         {:ok, active_id} = Otis.Channel.active_rendition(pid),
         playlist = Otis.State.Playlist.list(channel)
    do
      Enum.map(playlist, &rendition(&1, active_id))
    end
  end

  def status(%Otis.State.Channel{} = channel) do
    status = channel |> Map.from_struct |> Map.merge(channel_status(channel))
    struct(ChannelStatus, status)
  end

  def status(%Otis.State.Receiver{} = receiver) do
    status = receiver |> Map.from_struct |> Map.merge(receiver_status(receiver))
    struct(ReceiverStatus, status)
  end

  def rendition(rendition, active_id) do
    status =
      rendition
      |> Map.from_struct
      |> Map.merge(source_status(rendition))
      |> Map.merge(%{active: rendition.id == active_id})
    struct(RenditionStatus, status)
  end

  def receiver_status(receiver) do
    %{online: Otis.Receivers.connected?(receiver.id)}
  end

  def channel_status(channel) do
    %{playing: Otis.Channels.playing?(channel.id)}
  end

  def source_status(rendition) do
    source = Otis.State.Rendition.source(rendition)
    %{source: source}
  end
end

defimpl Poison.Encoder, for: Otis.State.ReceiverStatus do
  def encode(status, opts) do
    status
    |> Map.take([:id, :name, :volume, :online, :muted])
    |> Map.put(:channelId, status.channel_id)
    |> Poison.Encoder.encode(opts)
  end
end


defimpl Poison.Encoder, for: Otis.State.RenditionStatus do
  def encode(status, opts) do
    status
    |> Map.take([:id, :source, :active])
    |> Map.put(:playbackPosition, status.playback_position)
    |> Map.put(:sourceId, status.source_id)
    |> Map.put(:channelId, status.channel_id)
    |> Map.put(:nextId, status.next_id || "") # next id must not be nil
    |> Poison.Encoder.encode(opts)
  end
end
