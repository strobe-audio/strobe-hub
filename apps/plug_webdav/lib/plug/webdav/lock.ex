defmodule Plug.WebDAV.Lock do
  use GenServer

  alias __MODULE__

  @default_timeout 3_600
  @table :webdav_locks

  defstruct [
    :id,
    :path,
    :depth,
    type: :write,
    scope: :exclusive,
    timeout: @default_timeout
  ]

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def reset! do
    GenServer.call(__MODULE__, :reset)
  end

  def locks(root, path, time \\ now())

  def locks(root, path, time) when is_list(path) do
    abs_path = [root | path] |> Path.join()

    path
    |> search_paths()
    |> Enum.map(&Path.join([root | &1]))
    |> Enum.find_value([], &valid_locks_for_path(&1, abs_path, time))
  end

  def acquire_exclusive(root, path, opts \\ [timeout: @default_timeout, depth: :infinity])

  def acquire_exclusive(root, path, opts) when is_list(path) do
    case locks(root, path) do
      [] ->
        GenServer.call(__MODULE__, {:insert, root, path, opts})

      locks ->
        {:error, :duplicate, locks}
    end
  end

  def release(root, path, tokens) do
    GenServer.call(__MODULE__, {:release, root, path, tokens})
  end

  def supportedlock_property do
    [
      ~s(<d:supportedlock xmlns:d="DAV:">),
      "<d:lockentry>",
      "<d:lockscope><d:exclusive/></d:lockscope>",
      "<d:locktype><d:write/></d:locktype>",
      "</d:lockentry>",
      "</d:supportedlock>"
    ]
  end

  def lockdiscovery_property(locks) do
    [
      ~s(<d:lockdiscovery xmlns:d="DAV:">),
      Enum.map(locks, fn lock ->
        [
          "<d:activelock>",
          "<d:locktype><d:",
          to_string(lock.type),
          "/></d:locktype>",
          "<d:lockscope><d:",
          to_string(lock.scope),
          "/></d:lockscope>",
          "<d:depth>",
          depth_property(lock.depth),
          "</d:depth>",
          "<d:timeout>Second-",
          to_string(lock.timeout),
          "</d:timeout>",
          "<d:locktoken>",
          "<d:href>",
          lock.id,
          "</d:href>",
          "</d:locktoken>",
          "</d:activelock>"
        ]
      end),
      "</d:lockdiscovery>"
    ]
  end

  def all do
    :ets.foldl(fn {_path, _id, _depth, _expiry, lock}, locks -> [lock | locks] end, [], @table)
  end

  def init(_opts) do
    table =
      :ets.new(@table, [
        :named_table,
        :set,
        {:read_concurrency, true}
      ])

    schedule_expiry()
    {:ok, table}
  end

  def handle_call(:reset, _from, table) do
    :ets.delete_all_objects(table)
    {:reply, :ok, table}
  end

  def handle_call({:insert, root, path, opts}, _from, table) do
    abs_path = [root | path] |> Path.join()
    path = ["/" | path] |> Path.join()
    id = gen_id()
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    depth = Keyword.get(opts, :depth, :infinity) |> validate_depth()
    expiry = now() + timeout
    lock = %Lock{id: id, path: path, depth: depth, timeout: timeout}

    resp =
      case :ets.insert_new(table, {abs_path, id, depth, expiry, lock}) do
        false ->
          {:error, :duplicate}

        true ->
          {:ok, lock}
      end

    {:reply, resp, table}
  end

  def handle_call({:release, root, path, tokens}, _from, table) do
    lock_path = [root | path] |> Path.join()

    locks =
      tokens
      |> Enum.map(&match_lock_token(table, lock_path, &1))
      |> List.flatten()

    # I could do this with the single :ets.match_delete call but then
    # I wouldn't know if the token/path combo was valid
    resp =
      case locks do
        [] ->
          {:error, :invalid_path_token}

        l ->
          Enum.each(l, fn %Lock{id: id} ->
            :ets.match_delete(table, {lock_path, id, :_, :_, :_})
          end)

          :ok
      end

    {:reply, resp, table}
  end

  def handle_info(:remove_expired, table) do
    :ets.foldl(&collect_expired(&1, &2, now()), [], table)
    |> Enum.each(&:ets.delete(table, &1))

    schedule_expiry()
    {:noreply, table}
  end

  defp match_lock_token(table, path, id) do
    :ets.match(table, {path, id, :_, :_, :"$1"})
  end

  def now do
    :erlang.monotonic_time(:seconds)
  end

  def gen_id do
    "opaquelocktoken:#{UUID.uuid4()}"
  end

  # Search paths by decreasing specificity/depth
  # [something] -> [[something], []]
  # [something, else, here.txt] -> [[something, else, here.txt], [something, else], [something], []]
  defp search_paths([]), do: [[]]

  defp search_paths(path) when is_list(path) do
    search_paths(Enum.reverse(path), [path])
  end

  defp search_paths([_], search) do
    Enum.reverse([[] | search])
  end

  defp search_paths([_ | rest], search) do
    search_paths(rest, [Enum.reverse(rest) | search])
  end

  defp valid_locks_for_path(path, test_path, time) do
    case :ets.lookup(@table, path) do
      [] ->
        nil

      locks ->
        locks
        |> Enum.reject(&expired?(&1, time))
        |> Enum.filter(&in_scope?(&1, test_path))
        |> Enum.map(fn {_abs_path, _id, _depth, _expiry, lock} -> lock end)
    end
  end

  defp collect_expired({path, _, _, _, _} = lock, expired, time) do
    if expired?(lock, time) do
      [path | expired]
    else
      expired
    end
  end

  defp expired?({_path, _id, _depth, expiry, _lock}, time) do
    expiry <= time
  end

  defp in_scope?({path, _id, 0, _expiry, _lock}, path) do
    true
  end

  defp in_scope?({_lock_path, _id, 0, _expiry, _lock}, _path) do
    false
  end

  defp in_scope?({_lock_path, _id, :infinity, _expiry, _lock}, _path) do
    true
  end

  defp schedule_expiry do
    Process.send_after(self(), :remove_expired, 60 * 1000)
  end

  defp validate_depth(depth) when depth in [0, :infinity], do: depth
  defp validate_depth(_), do: :infinity

  defp depth_property(:infinity), do: "Infinity"
  defp depth_property(0), do: "0"
end
