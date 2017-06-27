defmodule Otis.State.Rendition do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Rendition
  alias __MODULE__
  alias Otis.State.Repo

  @primary_key {:id, :binary_id, autogenerate: true}

  @type t :: %__MODULE__{}

  schema "renditions" do
    field :position,          :integer
    field :next_id,           Ecto.UUID
    field :source_type,       :string
    field :source_id,         :string
    field :playback_position, :integer
    field :playback_duration, :integer

    belongs_to :channel, Otis.State.Channel, type: Ecto.UUID
  end

  def delete_all do
    Rendition |> Repo.delete_all
  end

  def delete!(rendition) do
    rendition |> Repo.delete!
  end

  def all do
    Rendition |> order_by([:channel_id, :position]) |> Repo.all
  end

  def for_channel(%Otis.Channel{id: id}) do
    for_channel(id)
  end
  def for_channel(channel_id) do
    Rendition |> where(channel_id: ^channel_id) |> order_by(:position) |> Repo.all
  end

  def restore(%Otis.Channel{id: id}) do
    restore(id)
  end
  def restore(channel_id) when is_binary(channel_id) do
    channel_id |> for_channel |> restore_rendition([])
  end

  defp restore_rendition([], renditions) do
    Enum.reverse(renditions)
  end
  defp restore_rendition([record | records], renditions) do
    restore_rendition(records, [list_entry(record) | renditions])
  end

  def reload({id, _playback_position, _rendition} = entry) do
    id |> find() |> reload_entry(entry)
  end

  def reload_entry(nil, original) do
    original
  end
  def reload_entry(record, {_id, _position, rendition}) do
    list_entry(record, rendition)
  end

  def list_entry(record) do
    list_entry(record, source(record))
  end
  def list_entry(record, source) do
    {record.id, record.playback_position, source}
  end

  def source(record) do
    record
    |> type
    |> Otis.Library.Source.Origin.load!
  end

  def for_source(type, id) when is_atom(type) do
    for_source(to_string(type), id)
  end
  def for_source(type, id) do
    Rendition |> where(source_id: ^id, source_type: ^type) |> Repo.all
  end

  def type(record) do
    record.source_type
    |> String.to_atom
    |> struct(id: record.source_id)
  end

  def find(id) do
    Rendition |> where(id: ^id) |> limit(1) |> Repo.one
  end

  def create!(rendition) do
    rendition |> sanitize_playback_duration() |> Repo.insert!
  end

  def update(rendition, fields) do
    rendition |> Ecto.Changeset.change(fields) |> Repo.update!
  end

  def sanitize_playback_duration(%Rendition{playback_duration: duration} = rendition) when is_atom(duration) do
    %Rendition{ rendition | playback_duration: nil }
  end
  def sanitize_playback_duration(rendition) do
    rendition
  end

  def played!(rendition, channel_id) do
    rendition |> delete!
    renumber(channel_id)
  end

  def renumber(channel_id) do
    channel_id
    |> for_channel
    |> Enum.with_index
    |> Enum.map(fn({s, p}) -> Ecto.Changeset.change(s, position: p) end)
    |> Enum.each(&Repo.update!/1)
  end

  def playback_position(rendition, position) do
    rendition
    |> Ecto.Changeset.change(playback_position: position)
    |> Repo.update!
  end

  def duration(rendition) do
    rendition.playback_duration - rendition.playback_position
  end
end
