defmodule Otis.State.Zone do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Zone
  alias Otis.State.Repo
  alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Poison.Encoder, only: [:id, :name, :volume, :position]}

  schema "zones" do
    field :name, :string
    field :volume, :float, default: 1.0
    field :position, :integer, default: 0

    has_many :receivers, Otis.State.Receiver
  end

  def first do
    Zone |> order_by(:position) |> limit(1) |> Repo.one
  end

  def all do
    Zone |> order_by(:position) |> Repo.all
  end

  def create!(id, name) do
    Repo.insert!(%Zone{id: id, name: name})
  end

  def delete!(zone) do
    Repo.delete!(zone)
  end

  def find(id) do
    Zone
    |> where(id: ^id)
    |> limit(1)
    |> Repo.one
  end

  def delete_all do
    Zone |> Repo.delete_all
  end

  def receivers(zone) do
    zone |> Ecto.assoc(:receivers) |> order_by(:name) |> Repo.all
  end

  def build_receiver(zone, opts \\ []) do
    zone |> Ecto.build_assoc(:receivers, opts)
  end

  def create_default! do
    create!(Otis.uuid, "Default zone")
  end

  def default_for_receiver do
    Zone
    |> order_by(:position)
    |> limit(1)
    |> Repo.one
  end

  def volume(zone, volume) do
    Changeset.change(zone, volume: volume) |> Repo.update!
  end
#
#   def create(name)
#
#   def destroy(zone)
#   def rename(zone)
#
#   # you can only add -- receivers are just moved around
#   # maps to a detach_receiver, attach_receiver pair
#   def add_receiver(zone, receiver)
#
#   def volume(zone, volume)
#   def mute(zone)
#
#   def replace_source_list(zone, source_list)
#   def insert_source(zone, source, position)
#   def remove_source(zone, source)
#   def position_source(zone, source, position)
#
#   def play_pause(zone)
#   def skip(zone, source) #
#   def scrub(zone, time) # time? what is the param here?
#
#
end
