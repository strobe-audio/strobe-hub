defmodule Otis.State.Source do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Source
  alias Otis.State.Repo

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "sources" do
    field :position,          :integer
    field :source_type,       :string
    field :source_id,         :string
    field :playback_position, :integer

    belongs_to :channel, Otis.State.Channel, type: Ecto.UUID
  end

  def delete_all do
    Source |> Repo.delete_all
  end

  def delete!(source) do
    source |> Repo.delete!
  end

  def all do
    Source |> order_by([:channel_id, :position]) |> Repo.all
  end

  def for_channel(%Otis.Channel{id: id}) do
    for_channel(id)
  end
  def for_channel(channel_id) do
    Source |> where(channel_id: ^channel_id) |> order_by(:position) |> Repo.all
  end

  def restore(%Otis.Channel{id: id}) do
    restore(id)
  end
  def restore(channel_id) when is_binary(channel_id) do
    channel_id |> for_channel |> restore_source([])
  end

  defp restore_source([], sources) do
    Enum.reverse(sources)
  end
  defp restore_source([record | records], sources) do
    restore_source(records, [list_entry(record) | sources])
  end

  def list_entry(record) do
    {record.id, record.playback_position, source(record)}
  end

  def source(record) do
    record.source_type
    |> String.to_atom
    |> struct(id: record.source_id)
    |> Otis.Source.Origin.load!
  end

  def find(id) do
    Source |> where(id: ^id) |> limit(1) |> Repo.one
  end

  def create!(source) do
    source |> Repo.insert!
  end

  def played!(source, channel_id) do
    source |> delete!
    renumber(channel_id)
  end

  def renumber(channel_id) do
    channel_id
    |> for_channel
    |> Enum.with_index
    |> Enum.map(fn({s, p}) -> Ecto.Changeset.change(s, position: p) end)
    |> Enum.each(&Repo.update!/1)
  end

  def playback_position(source, position) do
    source
    |> Ecto.Changeset.change(playback_position: position)
    |> Repo.update!
  end
end
