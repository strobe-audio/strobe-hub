defmodule Otis.State.Setting do
  use    Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias Otis.State.Repo
  alias __MODULE__

  defmodule JSON do
    @behaviour Ecto.Type

    def type, do: :json
    def cast(value), do: {:ok, value}
    def blank?(_), do: false

    def load(value), do: Poison.decode(value)
    def dump(value), do: Poison.encode(value)
  end

  schema "settings" do
    field :namespace, :string
    field :key,       :string
    field :value,     Otis.State.Setting.JSON
  end

  def put(ns, key, value) do
    %{namespace: to_string(ns), key: to_string(key), value: value}
    |> put_changeset()
    |> Repo.insert!
  end

  def get(ns, key) do
    _get(to_string(ns), to_string(key))
  end

  def namespace(ns) when is_atom(ns) do
    ns |>  Atom.to_string |> namespace
  end
  def namespace(ns) when is_binary(ns) do
    Setting
    |> where(namespace: ^ns)
    |> order_by([s], asc: s.key )
    |> Repo.all
    |> to_map
  end

  defp _get(ns, key) when is_binary(ns) and is_binary(key) do
    Setting
    |> where(namespace: ^ns, key: ^key)
    |> order_by([s], asc: s.key )
    |> Repo.one
    |> value_of
  end

  defp value_of(nil), do: :error
  defp value_of(%Setting{value: value}), do: {:ok, value}

  defp put_changeset(values) do
    Changeset.cast(%Setting{}, values, ~w(namespace key), ~w(value))
  end

  defp to_map(nil), do: :error
  defp to_map([]), do: :error
  defp to_map(settings) when is_list(settings) do
    m = settings
    |> Enum.map(fn(%Setting{key: key, value: value}) -> {String.to_atom(key), value} end)
    |> Enum.into(%{})
    {:ok, m}
  end
end
