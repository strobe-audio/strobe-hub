defmodule Otis.State.Receiver do
  use    Ecto.Schema
  import Ecto.Query

  alias Otis.State.Receiver
  alias Otis.State.Repo
  alias Ecto.Changeset

  @primary_key {:id, :string, []}
  @foreign_key_type :binary_id
  @derive {Poison.Encoder, only: [:id, :name, :volume, :zone_id]}

  schema "receivers" do
    field :name, :string
    field :volume, :float, default: 1.0

    belongs_to :zone, Otis.State.Zone
  end

  def all do
    Receiver |> order_by(:zone_id) |> Repo.all
  end

  def find(id, opts \\ []) do
    find_query(id, opts) |> Repo.one
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

  def create!(zone, attrs \\ []) do
    Otis.State.Zone.build_receiver(zone, attrs)
    |> Repo.insert!
    |> Repo.preload(:zone)
  end

  def delete_all do
    Receiver |> Repo.delete_all
  end

  def volume(receiver, volume) do
    Changeset.change(receiver, volume: volume) |> Repo.update!
  end
end
