defmodule Otis.State.Repo.Migrations.PersistReceiverMuted do
  use Ecto.Migration

  def change do
    alter table(:receivers) do
      add :muted, :boolean, default: false
    end
  end
end
