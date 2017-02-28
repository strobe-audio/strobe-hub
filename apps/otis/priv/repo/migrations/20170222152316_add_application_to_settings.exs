defmodule Otis.State.Repo.Migrations.AddApplicationToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :application, :string, null: false, default: ""
    end
    drop index(:settings, [:namespace, :key])
    create index(:settings, [:application, :namespace, :key], unique: true)
  end
end
