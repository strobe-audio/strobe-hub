defmodule Peel.DirWalker do
  require Logger
  use     GenServer

  def start_link(path, opts \\ %{})

  def start_link(list_of_paths, opts) when is_list(list_of_paths) do
    mappers = setup_mappers(opts)
    GenServer.start_link(__MODULE__, {list_of_paths, mappers})
  end

  def start_link(path, opts) when is_binary(path) do
    start_link([path], opts)
  end

  @doc """
  Return the next _n_ files from the lists of files, recursing into
  directories if necessary. Return `nil` when there are no files
  to return. (If there are fewer than _n_ files remaining, just those
  files are returned, and `nil` will be returned on the next call.

  ## Example

        iex> {:ok,d} = DirWalker.start_link "."
        {:ok, #PID<0.83.0>}
        iex> DirWalker.next(d)
        ["./.gitignore"]
        iex> DirWalker.next(d)
        ["./_build/dev/lib/dir_walter/.compile.elixir"]
        iex> DirWalker.next(d, 3)
        ["./_build/dev/lib/dir_walter/ebin/Elixir.DirWalker.beam",
         "./_build/dev/lib/dir_walter/ebin/dir_walter.app",
         "./_build/dev/lib/dir_walter/.compile.lock"]
        iex>
  """
  def next(iterator, n \\ 1) do
    GenServer.call(iterator, { :get_next, n })
  end

  @doc """
   Stops the DirWalker
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  @doc """
  Implement a stream interface that will return a lazy enumerable.

  ## Example

    iex> first_file = DirWalker.stream("/") |> Enum.take(1)

  """

  def stream(path_list) do
    Stream.resource(fn ->
        {:ok, dirw} = __MODULE__.start_link(path_list)
        dirw
      end ,
      fn(dirw) ->
        case next(dirw,1) do
          data when is_list(data) -> {data, dirw }
          _ -> {:halt, dirw}
        end
      end,
      fn(dirw) -> stop(dirw) end
    )
  end

  ##################
  # Implementation #
  ##################

  def handle_call({:get_next, _n}, _from, state = {[], _}) do
    {:reply, nil, state}
  end

  def handle_call({:get_next, n}, _from, {path_list, mappers}) do
    {result, new_path_list} = first_n(path_list, n, mappers, _result=[])
    {:reply, result, {new_path_list, mappers}}
  end

  def handle_call(:stop, from, state) do
      GenServer.reply(from, :ok)
      {:stop, :normal, state}
  end


  # If the first element is a list, then it represents a
  # nested directory listing. We keep it as a list rather
  # than flatten it in order to keep performance up.

  defp first_n([ [] | rest ], n, mappers, result)  do
    first_n(rest, n, mappers, result)
  end

  defp first_n([ [first] | rest ], n, mappers, result)  do
    first_n([ first | rest ], n, mappers, result)
  end

  defp first_n([ [first | nested] | rest ], n, mappers, result)  do
    first_n([ first | [ nested | rest ] ], n, mappers, result)
  end

  # Otherwise just a path as the first entry

  defp first_n(path_list, 0, _mappers, result), do: {result, path_list}
  defp first_n([], _n, _mappers, result),       do: {result, []}

  defp first_n([ path | rest ], n, mappers, result) do
    stat = File.stat!(path)
    case stat.type do
    :directory ->
      first_n([files_in(path) | rest],
              n,
              mappers,
              mappers.include_dir_names.(mappers.include_stat.(path, stat), result))

    :regular ->
        if mappers.matching.(path) do
        first_n(rest, n-1, mappers, [ mappers.include_stat.(path, stat) | result ])
      else
        first_n(rest, n, mappers, result)
      end

    true ->
      first_n(rest, n, mappers, result)
    end
  end

  defp files_in(path) do
    path
    |> :file.list_dir
    |> ignore_error(path)
    |> Enum.map(fn(rel) -> Path.join(path, rel) end)
  end

  def ignore_error({:error, type}, path) do
    Logger.info("Ignore folder #{path} (#{type})")
    []
  end

  def ignore_error({:ok, list}, _path), do: list


  defp setup_mappers(opts) do
    %{
      include_stat:
        one_of(opts[:include_stat],
               fn (path, _stat) -> path end,
               fn (path, stat)  -> {path, stat} end),

      include_dir_names:
        one_of(opts[:include_dir_names],
               fn (_path, result) -> result end,
               fn (path, result)  -> [ path | result ] end),
      matching:
        one_of(!!opts[:matching],
             fn _path -> true end,
             fn path  -> String.match?(path, opts[:matching]) end),
    }
  end

  defp one_of(bool, _if_false, if_true) when bool, do: if_true
  defp one_of(_bool, if_false, _if_true),          do: if_false
end

