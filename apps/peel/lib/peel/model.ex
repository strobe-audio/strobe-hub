defmodule Peel.Model do
  def search_version(string) do
    string
    |> String.normalize(:nfd)
    |> String.codepoints
    |> Enum.reject(&search_version_strip?/1)
    |> Enum.join
    |> normalize_whitespace
    |> String.downcase
  end

  # http://www.regular-expressions.info/unicode.html
  @mark_regex ~r/(\p{M}|\p{P}|\p{S}|\p{C})/u
  @whitespace_regex ~r/\p{Z}+/u

  def search_version_strip?(char) do
    Regex.match?(@mark_regex, char)
  end

  def normalize_whitespace(string) do
    Regex.replace(@whitespace_regex, string, " ")
  end

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

      def delete(m) do
        m |> Repo.delete!
      end

      # def search(title) do
        # match = "%#{title}%"
        # query = from(c in M,
        # where: like(unquote("c.#{Keyword.get(opts, :title_column, :title)}"), ^match))
        # query |> Repo.all
        # M |> ilike(:title, "%#{title}%") |> Repo.all
      # end

      def validate_record(nil, id) do
        raise "not valid"
      end
      def validate_record(m, id) do
        m
      end
    end
  end
end
