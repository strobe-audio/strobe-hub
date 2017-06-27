defmodule Otis.State.Repo.Migrations.PlaylistToLinkedList do
  use Ecto.Migration

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
    flush()

    Channel
    |> Repo.all
    |> Enum.each(fn(channel) ->
      [first | _] = renditions = channel.id |> Rendition.for_channel()
      link(renditions)
      Channel.update(channel, current_rendition_id: first.id)
    end)
  end

  defp link([]), do: nil
  defp link([_]), do: nil
  defp link([first | [next | _] = rest]) do
    first |> Rendition.update(next_id: next.id)
    link(rest)
  end
end
