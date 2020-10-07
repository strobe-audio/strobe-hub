defmodule Otis.State.Receiver do
  use Ecto.Schema
  import Ecto.Query

  alias Otis.State.{Receiver, Repo}
  alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Poison.Encoder, only: [:id, :name, :volume, :channel_id]}

  schema "receivers" do
    field(:name, :string)
    field(:volume, :float, default: 1.0)
    field(:muted, :boolean, default: false)

    belongs_to(:channel, Otis.State.Channel, type: Ecto.UUID)
  end

  def all do
    Receiver |> order_by(:channel_id) |> Repo.all()
  end

  def find(id, opts \\ []) do
    find_query(id, opts) |> Repo.one()
  end

  defp find_query(id, opts \\ [])

  defp find_query(id, preload: associations) do
    find_query(id) |> preload(^associations)
  end

  defp find_query(id, _opts) do
    Receiver
    |> where(id: ^id)
    |> limit(1)
  end

  def create!(channel, attrs \\ []) do
    Otis.State.Channel.build_receiver(channel, attrs)
    |> Repo.insert!()
    |> Repo.preload(:channel)
  end

  def delete_all do
    Receiver |> Repo.delete_all()
  end

  def volume(receiver, volume) do
    Changeset.change(receiver, volume: volume) |> Repo.update!()
  end

  def channel(receiver, channel_id) do
    Changeset.change(receiver, channel_id: channel_id) |> Repo.update!()
  end

  def rename(receiver, name) do
    Changeset.change(receiver, name: name) |> Repo.update!()
  end

  def mute(receiver, muted) do
    Changeset.change(receiver, muted: muted) |> Repo.update!()
  end
end
