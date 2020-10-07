defmodule Otis.State.Profile do
  use Ecto.Schema
  # import Ecto.Query

  alias Otis.State.Channel
  # alias Otis.State.Repo
  # alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  # @derive {Poison.Encoder, only: [:id, :name, :volume, :position]}

  schema "profiles" do
    field(:name, :string)
    field(:shared, :boolean, default: false)
    field(:position, :integer, default: 0)

    has_many(:channels, Channel)
  end
end
