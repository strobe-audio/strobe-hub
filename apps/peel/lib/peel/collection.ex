defmodule Peel.Collection do
  use Peel.Model

  alias __MODULE__
  alias Peel.{Album, Artist, Repo, Track}

  alias Ecto.Changeset

  schema "collections" do
    field(:name, :string)
    field(:path, :string)

    field(:album_count, :integer, default: 0)
    field(:artist_count, :integer, default: 0)
    field(:track_count, :integer, default: 0)
    field(:total_duration, :integer, default: 0)

    has_many(:albums, Album, on_delete: :delete_all)
    has_many(:artists, Artist, on_delete: :delete_all)
    has_many(:tracks, Track, on_delete: :delete_all)
  end

  @required_attrs ~w(id name path)
  @optional_attrs ~w()

  def create(name, root) do
    %{name: name, id: Ecto.UUID.generate(), path: nil}
    |> assign_root(root)
    |> create_changeset
    |> Repo.insert!()
  end

  def create_changeset(attrs) do
    %Collection{} |> Changeset.cast(attrs, @required_attrs, @optional_attrs)
  end

  def all do
    Collection |> order_by(:name) |> Repo.all()
  end

  def rename(collection, new_name) do
    root = Path.dirname(collection.path)

    renamed =
      collection
      |> Changeset.cast(
        %{name: new_name, path: Path.join(root, new_name)},
        @required_attrs,
        @optional_attrs
      )
      |> Repo.update!()

    {:ok, renamed}
  end

  def from_path(path) do
    [name | rest] = path |> split_path

    case name |> from_name() do
      {:ok, collection} ->
        {:ok, collection, join(rest)}

      err ->
        err
    end
  end

  def join([]), do: ""
  def join(path), do: Path.join(path)

  def abs_path(collection, rel_path) do
    [root(collection), rel_path] |> Path.join()
  end

  def from_name(name) do
    Collection |> where(name: ^name) |> limit(1) |> Repo.one() |> ok_tuple
  end

  def ok_tuple(nil), do: {:error, :not_found}
  def ok_tuple(coll), do: {:ok, coll}

  def split_path(path) when is_list(path), do: split_path(to_string(path))
  def split_path(<<"/", path::binary>>), do: Path.split(path)
  def split_path(path), do: Path.split(path)

  defp assign_root(collection, root) do
    %{collection | path: root(collection, root)}
  end

  def root(%Collection{path: nil} = collection) do
    raise "Invalid collection path #{inspect(collection)}"
  end

  def root(%Collection{path: path}), do: path
  def root(%{path: nil, name: name}, base), do: root(name, base)
  def root(%Collection{path: path}, _base), do: path

  def root(name, base) when is_binary(name) do
    Path.join([base, name])
  end

  def dav_path(%Collection{name: name}) do
    Path.join(["/", name])
  end
end
