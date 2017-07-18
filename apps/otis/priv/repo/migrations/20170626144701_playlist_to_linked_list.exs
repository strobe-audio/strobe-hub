defmodule Otis.State.Repo.Migrations.PlaylistToLinkedList do
  use Ecto.Migration

  import Ecto.Query

  alias Otis.State.Repo
  alias Otis.State.Channel
  alias Otis.State.Rendition

  def change do
    alter table(:channels) do
      add :current_rendition_id, :uuid
    end
    alter table(:renditions) do
      add :next_id, :uuid
    end
    create index(:renditions, [:next_id])
    flush()

    Channel
    |> Repo.all
    |> Enum.map(&migrate_channel/1)
  end

  defp migrate_channel(%Channel{id: channel_id} = channel) do
    renditions =
      Rendition
      |> where(channel_id: ^channel_id)
      |> order_by(:position)
      |> Repo.all
    link(renditions)
    head(channel, renditions)
  end

  defp link([first | [next | _] = rest]) do
    first |> Rendition.update(next_id: next.id)
    link(rest)
  end
  defp link(_), do: nil

  defp head(channel, [%Rendition{id: id} | _]) do
    Channel.update(channel, current_rendition_id: id)
  end
  defp head(channel, _) do
    channel
  end
end
