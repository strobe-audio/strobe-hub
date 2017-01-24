defmodule Otis.State.Repo.Migrations.CreateReceivers do
  use Ecto.Migration

  def change do
    create table(:receivers, primary_key: false) do
      add :id,      :uuid, primary_key: true
      add :channel_id, :uuid
      add :name,    :string
      add :volume,  :float, default: 1.0
    end
    create index(:receivers, [:channel_id])
  end
end
