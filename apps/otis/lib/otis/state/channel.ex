defmodule Otis.State.Channel do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Channel
  alias Otis.State.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Poison.Encoder, only: [:id, :name, :volume, :position]}

  @type t :: %__MODULE__{}

  schema "channels" do
    field :name, :string
    field :volume, :float, default: 1.0
    field :position, :integer, default: 0
    field :current_rendition_id, Ecto.UUID

    has_many :receivers, Otis.State.Receiver
    belongs_to :profile, Otis.State.Profile, type: Ecto.UUID
  end

  def changeset(channel, fields) do
    Ecto.Changeset.change(channel, fields)
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
    id |> find_query() |> Repo.one
  end

  def find!(id) do
    id |> find_query() |> Repo.one!
  end

  defp find_query(id) do
    Channel
    |> where(id: ^id)
    |> limit(1)
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
    changeset(channel, volume: volume) |> Repo.update!
  end

  def update(channel, fields) do
    channel |> changeset(fields) |> Repo.update!
  end

  def rename(channel, name) do
    channel |> changeset(name: name) |> Repo.update!
  end
end
