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

    belongs_to :zone, Otis.State.Zone, type: Ecto.UUID
  end

  def delete_all do
    Source |> Repo.delete_all
  end

  def delete!(source) do
    source |> Repo.delete!
  end

  def all do
    Source |> order_by([:zone_id, :position]) |> Repo.all
  end

  def for_zone(%Otis.Zone{id: id}) do
    for_zone(id)
  end
  def for_zone(zone_id) do
    Source |> where(zone_id: ^zone_id) |> order_by(:position) |> Repo.all
  end

  def restore(%Otis.Zone{id: id}) do
    restore(id)
  end
  def restore(zone_id) when is_binary(zone_id) do
    zone_id |> for_zone |> restore_source([])
  end

  defp restore_source([], sources) do
    Enum.reverse(sources)
  end
  defp restore_source([record | records], sources) do
    restore_source(records, [db_to_source(record) | sources])
  end

  defp db_to_source(record) do
    source = record.source_type
              |> String.to_atom
              |> struct(id: record.source_id)
              |> Otis.Source.Origin.load!
    {record.id, record.playback_position, source}
  end

  def find(id) do
    Source |> where(id: ^id) |> limit(1) |> Repo.one
  end

  def create!(source) do
    source |> Repo.insert!
  end

  def played!(source, zone_id) do
    source |> delete!
    renumber(zone_id)
  end

  def renumber(zone_id) do
    zone_id
    |> for_zone
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
