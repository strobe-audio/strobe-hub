defmodule Otis.State.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels, primary_key: false) do
      add :id,       :uuid,    primary_key: true
      add :name,     :string
      add :volume,   :float,   default: 1.0
      add :position, :integer, default: 0
    end
  end
end
