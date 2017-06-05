defmodule Peel.Modifications.Create do
  use     GenStage
  require Logger

  defmodule FileStatusCheck do
    use GenStage

    @config Application.get_env(:peel, Peel.Modifications.Create, [])

    @queue_delay Keyword.get(@config, :queue_delay, 0)

    alias Peel.Collection

    def start_link(opts) do
      GenStage.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      {:producer_consumer, {nil, :queue.new, opts}, subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
    end

    defp selector({:modification, {:create, _args}}), do: true
    defp selector(_evt), do: false

    def handle_events([], _from, state) do
      {:noreply, [], state}
    end
    def handle_events(events, _from, {timer, queue, opts}) do
      queue = Enum.reduce(events, queue, &:queue.in(&1, &2))
      {:noreply, [], {start_timer(timer), queue, opts}}
    end

    def handle_info(:test_pending, {_timer, queue, opts}) do
      {timer, queue, emit} = test_pending(queue, false, :queue.new, [])
      {:noreply, emit, {timer, queue, opts}}
    end

    defp test_pending(test_queue, start_timer, pending_queue, events) do
      case :queue.out(test_queue) do
        {{:value, evt}, test_queue} ->
          case test_event(evt) do
            {:ok, evt} ->
              test_pending(test_queue, start_timer, pending_queue, [evt|events])
            {:wait, evt} ->
              test_pending(test_queue, true, :queue.in(evt, pending_queue), events)
            :discard ->
              test_pending(test_queue, start_timer, pending_queue, events)
          end
        {:empty, _test_queue} ->
          {start_timer(start_timer), pending_queue, events}
      end
    end

    defp test_event({:modification, {:create, [:collection, _path]}} = evt) do
      {:ok, evt}
    end
    defp test_event({:modification, {:create, [:file, path]}} = evt) do
      with {:ok, collection, track_path} <- Collection.from_path(path) |> IO.inspect,
           :ok <- exists?(collection, track_path),
           :ok <- not_empty(collection, track_path)
      do
        {:ok, evt}
      else
        {:error, :invalid_collection} = err ->
          IO.inspect [:ready?, err, path]
          :discard
        err ->
          IO.inspect [:ready?, err, path]
          {:wait, evt}
      end
    end

    defp start_timer(timer) when timer in [nil, true] do
      Process.send_after(self(), :test_pending, @queue_delay)
    end
    defp start_timer(false) do
      nil
    end
    defp start_timer(timer) do
      timer
    end

    def exists?(collection, path) do
      collection |> Collection.abs_path(path) |> exists?
    end
    def exists?(path) do
      IO.inspect [:exists?, path]
      if File.exists?(path) do
        :ok
      else
        :error
      end
    end

    def not_empty(collection, path) do
      collection |> Collection.abs_path(path) |> not_empty
    end
    def not_empty(path) do
      IO.inspect [:empty?, path]
      case File.stat(path) do
        {:ok, %File.Stat{size: size}} when size > 0 ->
          :ok
        {:ok, _stat} ->
          :empty
        {:error, _} ->
          :error
      end
    end

  end

  alias Peel.Collection

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {root, opts} = Keyword.pop(opts, :root)
    {:consumer, {root, opts}, subscribe_to: [Peel.Modifications.Create.FileStatusCheck]}
  end

  # defp selector({:modification, {:create, _args}}), do: true
  # defp selector(_evt), do: false

  def handle_events([], _from, opts) do
    {:noreply, [], opts}
  end
  def handle_events([event|events], from, opts) do
    {:ok, opts} = handle_event(event, opts)
    handle_events(events, from, opts)
  end

  def handle_event({:modification, {:create, [:collection, name]} = evt}, {root, _} = opts) do
    case Collection.from_name(name) do
      {:ok, _collection} ->
        Logger.warn "Attempt to create existing collection #{inspect name}"
      _err ->
        _collection = Collection.create(name, root)
        Peel.Webdav.Modifications.complete(evt)
    end
    {:ok, opts}
  end
  def handle_event({:modification, {:create, [:file, path]} = evt}, opts) do
    IO.inspect [:handle_event, evt]
    {:ok, collection, path} = Collection.from_path(path) |> IO.inspect
    case Peel.Importer.track(collection, path) |> IO.inspect do
      {:ok, track} ->
        Logger.info "Added track #{ track.id } #{ track.performer } > #{ track.album_title } > #{ inspect track.title }"
      {:ignored, _reason} ->
        nil
      err ->
        Logger.error "Error importing path #{path} -> #{inspect err}"
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, opts}
  end
end
