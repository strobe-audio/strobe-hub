defmodule Otis.State.Repo.Migrations.CreateSourceLists do
  use Ecto.Migration

  def change do
    create table(:sources, primary_key: false) do
      add :id,          :uuid, primary_key: true
      add :zone_id,     :string
      add :position,    :integer
      add :source_type, :string
      add :source_id,   :string
    end
    create index(:sources, [:zone_id])
  end
end
