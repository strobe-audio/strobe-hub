defmodule Peel.Model do
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query
      use    Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true}

      alias  Peel.Repo
      alias  __MODULE__, as: M

      def find!(id) do
        id |> find |> validate_record(id)
      end

      def find(id) do
        M |> where(id: ^id) |> limit(1) |> Repo.one
      end

      def first do
        M |> order_by(:id) |> limit(1) |> Repo.one
      end

      def all do
        M |> Repo.all
      end

      def delete_all do
        M |> Repo.delete_all
      end

      # def search(title) do
        # match = "%#{title}%"
        # query = from(c in M,
        # where: like(unquote("c.#{Keyword.get(opts, :title_column, :title)}"), ^match))
        # query |> Repo.all
        # M |> ilike(:title, "%#{title}%") |> Repo.all
      # end

      def validate_record(m, id) do
        # %M{id: ^id} = m
      end
    end
  end
end
