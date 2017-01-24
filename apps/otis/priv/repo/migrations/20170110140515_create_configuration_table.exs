defmodule Otis.State.Repo.Migrations.CreateConfigurationTable do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :namespace, :string, null: false
      add :key,       :string, null: false
      add :value,     :text, default: ""
    end
    create index(:settings, [:namespace, :key], unique: true)
  end
end
