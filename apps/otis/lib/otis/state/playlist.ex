defmodule Otis.State.Playlist do
  @moduledoc """
  Represents a db-backed playlist, implemented as a linked list of Renditions.
  The first element in the playlist is pointed to by
  `channels.current_rendition_id` and each rendition points to the next in the
  list using `renditions.next_id`.
  """

  import Ecto.Query

  alias Otis.State.Rendition
  alias Otis.State.Channel
  alias Otis.State.Repo

  require Logger

  @doc """
  Retreives the active rendition for the channel
  """
  @spec current(Channel.t) :: Rendition.t | nil
  def current(%Channel{current_rendition_id: nil}), do: nil

  def current(%Channel{current_rendition_id: current_rendition_id}) do
    find!(current_rendition_id)
  end

  @doc """
  Returns channel playlist as a stream of Renditions.

  This allows for use of the normal Enum/Stream functions on the playlist
  without the potential cost of loading the entire list from the db.
  """
  @spec stream(Channel.t) :: Enumerable.t
  def stream(%Channel{current_rendition_id: current_rendition_id}) do
    stream_from(current_rendition_id)
  end

  def stream_reverse(%Channel{current_rendition_id: nil} = channel) do
    channel |> last() |> stream_reverse_from()
  end
  def stream_reverse(%Channel{current_rendition_id: current_rendition_id}) do
    current_rendition_id |> previous() |> stream_reverse_from()
  end

  defp stream_reverse_from(nil), do: []
  defp stream_reverse_from(first) do
    Stream.resource(fn -> first end, &stream_prev/1, fn(_)-> :ok end)
  end

  defp stream_prev(nil), do: {:halt, nil}
  defp stream_prev(current) do
    previous = previous(current.id)
    {[current], previous}
  end

  @doc """
  Retreives the playlist for the given channel
  """
  @spec list(Channel.t) :: [Rendition.t]
  def list(channel) do
    stream(channel) |> Enum.to_list()
  end

  @doc """
  Returns the list of renditions after mapping through the given function
  """
  @spec map(Channel.t, (Rendition.t -> term)) :: list
  def map(channel, fun) do
    stream(channel) |> Enum.map(fun)
  end

  @doc """
  Returns the last entry in a Channel's playlist
  """
  @spec last(Channel.t) :: Rendition.t | nil
  def last(%Channel{id: id}) do
    Rendition
    |> where([r], r.channel_id == ^id and is_nil(r.next_id))
    |> Repo.one
  end

  @doc """
  Moves the Channel's playist forward to the given rendition.
  """
  @spec advance!(Channel.t, binary) :: {Channel.t, [Rendition.t]}
  def advance!(%Channel{} = channel, skip_id) do
    skipped = skipped(channel, skip_id)
    {skip(channel, skip_id), skipped}
  end

  defp skip(channel, skip_id) do
    channel |> Ecto.Changeset.change(current_rendition_id: skip_id) |> Repo.update!
  end

  defp skipped(channel, skip_id) do
    stream(channel) |> Enum.take_while(fn(r) -> r.id != skip_id end)
  end

  @doc """
  Appends the given (new) renditions to the channel's playlist.
  """
  @spec append!(Channel.t, [Rendition.t]) :: {Channel.t, [Rendition.t]}
  def append!(%Channel{id: id} = channel, renditions) do
    last = channel |> last()
    [last | renditions] |> append(id, []) |> after_append(channel)
  end

  defp append([rendition], channel_id, inserted) do
    entry =
      rendition
      |> Ecto.Changeset.change(next_id: nil, channel_id: channel_id)
      |> Repo.insert!(on_conflict: :nothing)
    [entry | inserted] |> Enum.reverse()
  end
  defp append([nil | rest], channel_id, inserted) do
    append(rest, channel_id, inserted)
  end
  defp append([first | [next | _] = rest], channel_id, inserted) do
    append(rest, channel_id, [insert_linked(first, next.id, channel_id) | inserted])
  end

  defp after_append([], channel) do
    {channel, []}
  end
  defp after_append([head | _] = inserted, %Channel{current_rendition_id: nil} = channel) do
    {channel |> skip(head.id), inserted}
  end
  defp after_append([_ | inserted], channel) do
    {channel, inserted}
  end

  @doc """
  Prepends the given (new) renditions to the channel's playlist.
  """
  @spec prepend!(Channel.t, [Rendition.t]) :: {Channel.t, [Rendition.t]}
  def prepend!(%Channel{current_rendition_id: nil} = channel, renditions) do
    append!(channel, renditions)
  end

  def prepend!(%Channel{current_rendition_id: current_rendition_id} = channel, renditions) do
    first = current_rendition_id |> find!()
    renditions |> Enum.concat([first]) |> prepend(channel.id, []) |> after_prepend(channel)
  end

  defp prepend([], _channel_id, inserted) do
    inserted |> Enum.reverse()
  end
  defp prepend([_rendition], _channel_id, inserted) do
    inserted |> Enum.reverse()
  end
  defp prepend([first | [next | _] = rest], channel_id, inserted) do
    prepend(rest, channel_id, [insert_linked(first, next.id, channel_id) | inserted])
  end

  defp after_prepend([], channel) do
    {channel, []}
  end
  defp after_prepend([head | _] = inserted, channel) do
    {channel |> skip(head.id), inserted}
  end

  @doc """
  Inserts new renditions after the given id
  """
  @spec insert_after!(Channel.t, binary, [Rendition.t]) :: {Channel.t, [Rendition.t]}
  def insert_after!(%Channel{id: channel_id} = channel, position_id, renditions) do
    insertion = %Rendition{next_id: next_id} = find!(position_id)
    [insertion | renditions] |> insert(channel_id, next_id, []) |> after_insert(channel)
  end

  defp insert([], _channel_id, _next_id, inserted) do
    inserted |> Enum.reverse()
  end
  defp insert([last], channel_id, next_id, inserted) do
    rendition = last |> insert_linked(next_id, channel_id)
    [rendition | inserted] |> Enum.reverse()
  end
  defp insert([first | [next | _] = rest], channel_id, next_id, inserted) do
    insert(rest, channel_id, next_id, [insert_linked(first, next.id, channel_id) | inserted])
  end

  defp after_insert([_ | inserted], channel) do
    {channel, inserted}
  end

  @doc """
  Delete `n` items from playlist starting from `start_id`
  """
  @spec delete!(Channel.t, binary, non_neg_integer) :: {Channel.t, [Rendition.t]}
  def delete!(channel, _start_id, 0) do
    {channel, []}
  end
  def delete!(channel, start_id, n) do
    previous = previous(start_id)
    {drop, keep} = stream_from(start_id) |> Enum.take(n + 1) |> Enum.split(n)
    channel =
      case keep do
        [] -> relink(channel, previous, nil)
        [rendition] ->
          channel
          |> relink(previous, rendition)
          |> relink_head(drop, keep)
      end
    delete_renditions(drop)
    {channel, drop}
  end

  @doc """

  """
  @spec clear!(Channel.t, nil | binary) :: {Channel.t, [Rendition.t]}
  def clear!(channel, after_id \\ nil)
  def clear!(%Channel{current_rendition_id: nil} = channel, _after_id) do
    {channel, []}
  end
  def clear!(channel, nil) do
    drop = list(channel)
    delete_renditions(drop)
    channel = channel |> relink(nil, nil)
    {channel, drop}
  end
  def clear!(channel, after_id) when is_binary(after_id) do
    after_rendition = find!(after_id)
    drop = stream_from(after_rendition.next_id) |> Enum.to_list()
    delete_renditions(drop)
    channel = channel |> relink(after_rendition, nil)
    {channel, drop}
  end

  defp relink(nil, _head, _next_id) do
    Logger.warn "Channel is nil"
    nil
  end
  defp relink(channel, head, %Rendition{id: next_id}) do
    relink(channel, head, next_id)
  end
  defp relink(channel, nil, next_id) do
    channel
    |> Ecto.Changeset.change(current_rendition_id: next_id)
    |> Repo.update!
  end
  defp relink(channel, %Rendition{} = rendition, next_id) do
    rendition
    |> Ecto.Changeset.change(next_id: next_id)
    |> Repo.update!
    channel
  end

  defp relink_head(channel, [dropped | _], [kept | _]) do
    if channel.current_rendition_id == dropped.id do
      relink(channel, nil, kept.id)
    else
      channel
    end
  end

  defp delete_renditions([]), do: nil
  defp delete_renditions(renditions) do
    ids = Enum.map(renditions, fn(%Rendition{id: id}) -> id end)
    Rendition
    |> where([r], r.id in ^ids)
    |> Repo.delete_all()
  end

  defp insert_linked(rendition, next_id, channel_id) do
    rendition
    |> Ecto.Changeset.change(next_id: next_id, channel_id: channel_id)
    |> Repo.insert_or_update!
  end

  defp find!(id) do
    Rendition |> where(id: ^id) |> Repo.one!
  end

  # Previous might legitimately be nil so don't use Repo.one!
  defp previous(id) do
    Rendition |> where(next_id: ^id) |> Repo.one
  end

  # Returns a stream of renditions starting at the given id
  defp stream_from(nil), do: []
  defp stream_from(head_id) do
    Stream.resource(fn -> head_id end, &stream_next/1, fn(_)-> :ok end)
  end

  defp stream_next(nil), do: {:halt, nil}
  defp stream_next(id) do
    rendition = find!(id)
    {[rendition], rendition.next_id}
  end
end
