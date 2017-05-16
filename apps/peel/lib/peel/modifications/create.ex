defmodule Peel.Modifications.Create do
  use     GenStage
  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  defmodule FileStatusCheck do
    use GenStage

    def start_link do
      GenStage.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_opts) do
      {:producer_consumer, {nil, :queue.new}, subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
    end

    defp selector({:modification, {:create, _args}}), do: true
    defp selector(_evt), do: false

    def handle_events([], _from, state) do
      {:noreply, [], state}
    end
    def handle_events(events, _from, {timer, queue}) do
      queue = Enum.reduce(events, queue, &:queue.in(&1, &2))
      {:noreply, [], {start_timer(timer), queue}}
    end

    def handle_info(:test_pending, {_timer, queue}) do
      {timer, queue, emit} = test_pending(queue, false, :queue.new, [])
      {:noreply, emit, {timer, queue}}
    end

    defp test_pending(test_queue, start_timer, pending_queue, events) do
      case :queue.out(test_queue) do
        {{:value, evt}, test_queue} ->
          case test_event(evt) do
            {:ok, evt} ->
              test_pending(test_queue, start_timer, pending_queue, [evt|events])
            {:wait, evt} ->
              test_pending(test_queue, true, :queue.in(evt, pending_queue), events)
          end
        {:empty, _test_queue} ->
          {start_timer(start_timer), pending_queue, events}
      end
    end

    defp test_event({:modification, {:create, [path]}} = evt) do
      with :ok <- exists?(path),
        :ok <- not_empty(path)
      do
        {:ok, evt}
      else

        err ->
          IO.inspect [:wait, path]
          err
      end
    end

    defp start_timer(timer) when timer in [nil, true] do
      Process.send_after(self(), :test_pending, 2_000)
    end
    defp start_timer(false) do
      nil
    end
    defp start_timer(timer) do
      timer
    end

    def exists?(path) do
      if File.exists?(path) do
        :ok
      else
        :error
      end
    end

    def not_empty(path) do
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

  def init(_opts) do
    {:consumer, [], subscribe_to: [Peel.Modifications.Create.FileStatusCheck]}
  end

  # defp selector({:modification, {:create, _args}}), do: true
  # defp selector(_evt), do: false

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:modification, {:create, [path]} = evt}, state) do
    case Peel.Importer.track(path) do
      {:ok, track} ->
        Logger.info "Added track #{ track.id } #{ track.performer } > #{ track.album_title } > #{ inspect track.title }"
      {:ignored, _reason} ->
        nil
      {:error, err} ->
        Logger.error "Error importing path #{path} -> #{inspect err}"
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, state}
  end

  def metadata(path) do
    Peel.Importer.metadata(path)
  end
end
