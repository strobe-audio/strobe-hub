defmodule Peel.Model do
  defmacro __using__(_) do
    quote do
      import Ecto.Query
      use    Ecto.Schema

      alias  Peel.Repo
      alias  __MODULE__, as: M

      def first do
        M |> order_by(:id) |> limit(1) |> Repo.one
      end

      def all do
        M |> Repo.all
      end

      def delete_all do
        M |> Repo.delete_all
      end
    end
  end
end
