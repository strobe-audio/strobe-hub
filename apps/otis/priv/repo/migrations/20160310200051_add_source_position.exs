defmodule Otis.State.Repo.Migrations.AddSourcePosition do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :playback_position, :integer, default: 0
    end
  end
end
