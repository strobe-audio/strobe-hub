defmodule Otis.State do
  require Logger

  defmodule ChannelStatus do
    @derive {Poison.Encoder, only: [:id, :name, :volume, :position, :playing]}

    defstruct [:id, :name, :volume, :position, :playing]
  end

  defmodule ReceiverStatus do
    defstruct [:id, :name, :volume, :online, :channel_id, :online]
  end

  defmodule SourceStatus do
    defstruct [:id, :position, :source, :playback_position, :source_id, :channel_id]
  end

  @doc "Returns the current state from the db"
  def current do
    channels = channels()
    %{ channels: channels, receivers: receivers(), sources: sources() }
  end

  defp channels do
    # TODO:
    # - playlist
    # - current song
    Enum.map Otis.State.Channel.all, &status/1
  end

  def receivers do
    # TODO: find live state
    Enum.map Otis.State.Receiver.all, &status/1
  end

  def sources do
    Enum.map Otis.State.Source.all, &source/1
  end

  def status(%Otis.State.Channel{} = channel) do
    status = channel |> Map.from_struct |> Map.merge(channel_status(channel))
    struct(ChannelStatus, status)
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

  def channel_status(channel) do
    %{playing: Otis.Channels.playing?(channel.id)}
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
    |> Map.put(:channelId, status.channel_id)
    |> Poison.Encoder.encode(opts)
  end
end

defimpl Poison.Encoder, for: Otis.State.SourceStatus do
  def encode(status, opts) do
    status
    |> Map.take([:id, :position, :source])
    |> Map.put(:playbackPosition, status.playback_position)
    |> Map.put(:sourceId, status.source_id)
    |> Map.put(:channelId, status.channel_id)
    |> Poison.Encoder.encode(opts)
  end
end
