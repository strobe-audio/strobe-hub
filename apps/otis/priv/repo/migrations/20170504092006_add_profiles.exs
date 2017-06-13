defmodule Otis.State.Repo.Migrations.AddProfiles do
  use Ecto.Migration

  alias Otis.State.Repo

  def change do
    profile_id = Otis.uuid()

    create table(:profiles, primary_key: false) do
      add :id,       :uuid,    primary_key: true
      add :name,     :string
      add :shared,   :boolean, default: false
      add :position, :integer, default: 0
    end

    alter table(:channels) do
      add :profile_id, :uuid
    end

    create index(:channels, [:profile_id])

    # make sure db has new table & columns
    flush()

    profile = %Otis.State.Profile{
      id: profile_id,
      name: "Shared",
      shared: true,
      position: 0,
    } |> Repo.insert!

    Repo.update_all(Otis.State.Channel, set: [profile_id: profile.id])
  end
end
