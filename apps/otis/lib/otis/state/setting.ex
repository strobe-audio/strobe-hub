defmodule Otis.State.Setting do
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias Otis.State.Repo
  alias __MODULE__

  defmodule JSON do
    @behaviour Ecto.Type

    def type, do: :json
    def cast(value), do: {:ok, value}
    def blank?(_), do: false

    def load("") do
      {:ok, ""}
    end

    def load(value) do
      Poison.decode(value)
    end

    def dump(value), do: Poison.encode(value)
  end

  schema "settings" do
    field(:application, :string)
    field(:namespace, :string)
    field(:key, :string)
    field(:value, Otis.State.Setting.JSON)
  end

  def put(app, ns, key, _value) when app == "" or ns == "" or key == "", do: :error

  def put(app, ns, key, value) do
    put!(app, ns, key, value)
  rescue
    e in Sqlite.DbConnection.Error ->
      stacktrace = System.stacktrace()

      case e do
        %Sqlite.DbConnection.Error{sqlite: %{code: :constraint}} ->
          delete(app, ns, key)
          put(app, ns, key, value)

        _ ->
          reraise(e, stacktrace)
      end
  end

  def get(app, ns, key) do
    _get(to_string(app), to_string(ns), to_string(key)) |> value_of()
  end

  def application(app) when is_binary(app) do
    Setting
    |> where(application: ^app)
    |> order_by([s], asc: s.namespace, asc: s.key)
    |> Repo.all()
    |> to_application_map
  end

  def application(app) do
    application(to_string(app))
  end

  def namespace(app, ns) when is_binary(app) and is_binary(ns) do
    Setting
    |> where(application: ^app, namespace: ^ns)
    |> order_by([s], asc: s.key)
    |> Repo.all()
    |> to_namespace_map
  end

  def namespace(app, ns) do
    namespace(to_string(app), to_string(ns))
  end

  defp delete(app, ns, key) when is_binary(app) and is_binary(ns) and is_binary(key) do
    Setting
    |> where(application: ^app, namespace: ^ns, key: ^key)
    |> Repo.delete_all()
  end

  defp delete(app, ns, key), do: delete(to_string(app), to_string(ns), to_string(key))

  defp put!(app, ns, key, value) do
    %{application: to_string(app), namespace: to_string(ns), key: to_string(key), value: value}
    |> put_changeset()
    |> Repo.insert!()
  end

  defp _get(app, ns, key) when is_binary(app) and is_binary(ns) and is_binary(key) do
    Setting
    |> where(application: ^app, namespace: ^ns, key: ^key)
    |> order_by([s], asc: s.key)
    |> Repo.one()
  end

  defp value_of(nil), do: :error
  defp value_of(%Setting{value: value}), do: {:ok, value}

  defp put_changeset(values) do
    Changeset.cast(%Setting{}, values, ~w(application namespace key value)a)
  end

  defp to_application_map(nil), do: :error
  defp to_application_map([]), do: :error

  defp to_application_map(settings) do
    {:ok, to_application_map!(settings)}
  end

  defp to_application_map!(settings) do
    settings
    |> Enum.group_by(fn %Setting{namespace: ns} -> ns end)
    |> Enum.map(fn {ns, values} ->
      {String.to_atom(ns), to_namespace_map!(values)}
    end)
    |> Enum.into(%{})
  end

  defp to_namespace_map(nil), do: :error
  defp to_namespace_map([]), do: :error

  defp to_namespace_map(settings) when is_list(settings) do
    m = to_namespace_map!(settings)
    {:ok, m}
  end

  defp to_namespace_map!(settings) when is_list(settings) do
    settings
    |> Enum.map(fn %Setting{key: key, value: value} -> {String.to_atom(key), value} end)
    |> Enum.into(%{})
  end
end
