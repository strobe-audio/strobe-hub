defmodule Otis.State.Repo.Migrations.CreateSourceLists do
  use Ecto.Migration

  def change do
    create table(:renditions, primary_key: false) do
      add :id,          :uuid, primary_key: true
      add :channel_id,     :uuid
      add :position,    :integer
      add :source_type, :string
      add :source_id,   :string
      add :playback_position, :integer, default: 0
      add :playback_duration, :integer, default: 0
    end
    create index(:renditions, [:channel_id])
  end
end
