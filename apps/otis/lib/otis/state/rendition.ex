defmodule Otis.State.Rendition do
  use    Ecto.Schema
  import Ecto.Query

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

  def from_source(source) do
    {source_id, source_type, duration} = source_info(source)
    %Rendition{
      id: Otis.uuid(),
      playback_position: 0,
      playback_duration: duration,
      source_id: source_id,
      source_type: source_type,
    } |> Rendition.sanitize_playback_duration()
  end

  defp source_info(source) do
    source_id = Otis.Library.Source.id(source)
    source_type = source |> Otis.Library.Source.type() |> to_string
    {:ok, duration} = source |> Otis.Library.Source.duration()
    {source_id, source_type, duration}
  end

  def sanitize_playback_duration(%Rendition{playback_duration: duration} = rendition) when is_atom(duration) do
    %Rendition{rendition | playback_duration: nil}
  end
  def sanitize_playback_duration(rendition) do
    rendition
  end

  def played!(rendition, _channel_id) do
    rendition
  end

  # Do we want to delete skipped renditions? Doing so would mean that if we go
  # back through the playlist, only tracks that were played would appear in the
  # history. If we don't delete them then the historical view reflects not the
  # tracks we played but instead the tracks we added.
  def skipped!(rendition) do
    rendition |> Rendition.delete!()
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
