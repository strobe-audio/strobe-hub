defmodule Otis.State.Channel do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Channel
  alias Otis.State.Repo
  alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Poison.Encoder, only: [:id, :name, :volume, :position]}

  schema "channels" do
    field :name, :string
    field :volume, :float, default: 1.0
    field :position, :integer, default: 0

    has_many :receivers, Otis.State.Receiver
    belongs_to :profile, Otis.State.Profile, type: Ecto.UUID
  end

  def first do
    Channel |> order_by(:position) |> limit(1) |> Repo.one
  end

  def all do
    Channel |> order_by(:position) |> Repo.all
  end

  def create!(id, name) do
    Repo.insert!(%Channel{id: id, name: name})
  end

  def delete!(channel) do
    Repo.delete!(channel)
  end

  def find(id) do
    Channel
    |> where(id: ^id)
    |> limit(1)
    |> Repo.one
  end

  def delete_all do
    Channel |> Repo.delete_all
  end

  def receivers(channel) do
    channel |> Ecto.assoc(:receivers) |> order_by(:name) |> Repo.all
  end

  def build_receiver(channel, opts \\ []) do
    channel |> Ecto.build_assoc(:receivers, opts)
  end

  def create_default! do
    create!(Otis.uuid, "Default channel")
  end

  def default_for_receiver do
    Channel
    |> order_by(:position)
    |> limit(1)
    |> Repo.one
  end

  def volume(channel, volume) do
    Changeset.change(channel, volume: volume) |> Repo.update!
  end

  def rename(channel, name) do
    Changeset.change(channel, name: name) |> Repo.update!
  end
#
#   def create(name)
#
#   def destroy(channel)
#   def rename(channel)
#
#   # you can only add -- receivers are just moved around
#   # maps to a detach_receiver, attach_receiver pair
#   def add_receiver(channel, receiver)
#
#   def volume(channel, volume)
#   def mute(channel)
#
#   def replace_source_list(channel, source_list)
#   def insert_source(channel, source, position)
#   def remove_source(channel, source)
#   def position_source(channel, source, position)
#
#   def play_pause(channel)
#   def skip(channel, source) #
#   def scrub(channel, time) # time? what is the param here?
#
#
end
