defmodule Otis.State.Repo.Migrations.CreateReceivers do
  use Ecto.Migration

  def change do
    create table(:receivers, primary_key: false) do
      add :id, :string, primary_key: true
      add :zone_id, :string, references(:zones)
      add :name, :string
      add :volume, :float, default: 1.0
    end
    create index(:receivers, [:zone_id])
  end
end
