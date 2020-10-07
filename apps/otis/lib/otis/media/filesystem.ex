defmodule Otis.Media.Filesystem do
  defmacro __using__(opts) do
    quote location: :keep do
      {root, at} =
        case unquote(opts) do
          path when is_binary(path) ->
            path

          [root: root, at: at] ->
            {root, at}

          [app: app, mod: mod] ->
            options = Application.get_env(app, mod)
            {Keyword.get(options, :root, "_state/fs"), Keyword.get(options, :at, "/fs")}
        end

      @root Path.expand(root)
      @at at

      import Path, only: [join: 1]

      def root do
        @root
      end

      def from do
        @root
      end

      def at do
        @at
      end

      def copy!(ns, filename, path, opts \\ [optimize: false]) do
        {:ok, url} = copy(ns, filename, path, opts)
        url
      end

      def copy(ns, filename, path, opts \\ [optimize: false]) do
        _copy(ns, filename, path, opts, File.exists?(path))
      end

      def location(ns, filename, opts \\ [optimize: false])

      def location(ns, filename, opts) do
        path = path!(ns, filename, opts)
        url = url(ns, filename, opts)
        {:ok, path, url}
      end

      def path!(ns, filename, opts) do
        path(ns, filename, opts) |> mkpath
      end

      def path(ns, filename, opts) do
        optimized_path(@root, ns, filename, opts)
      end

      def url(ns, filename, opts \\ [optimize: false])

      def url(ns, filename, opts) do
        optimized_path(@at, ns, filename, opts)
      end

      def optimized_path(root, ns, filename, opts) do
        join(List.flatten([root, ns, optimize(filename, opts), filename]))
      end

      defp optimize(filename, optimize: true), do: optimize(filename, optimize: 1)

      defp optimize(filename, optimize: n) when is_integer(n) and n > 0 do
        _optimize(filename, n, [])
      end

      defp optimize(_filename, _opts) do
        []
      end

      defp _optimize(_filename, 0, acc) do
        Enum.reverse(acc)
      end

      defp _optimize(<<c::binary-size(1), filename::binary>>, levels, acc) do
        _optimize(filename, levels - 1, [c | acc])
      end

      defp _copy(_ns, _filename, _src_path, _opts, false) do
        {:error, :enoent}
      end

      defp _copy(ns, filename, src_path, opts, true) do
        with :ok <- File.cp(src_path, path!(ns, filename, opts)) do
          {:ok, url(ns, filename, opts)}
        end
      end

      defp mkpath(path) do
        :ok = path |> Path.dirname() |> File.mkdir_p()
        path
      end

      defp mkdir(dir) do
        :ok = dir |> File.mkdir_p()
        dir
      end
    end
  end
end
