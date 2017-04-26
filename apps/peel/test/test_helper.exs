defmodule TestEventHandler do
  use GenStage

  def attach do
    {:ok, _pid} = start_link(self())
    :ok
  end

  def start_link(parent) do
    GenStage.start_link(__MODULE__, parent)
  end

  def init(parent) do
    {:consumer, parent, subscribe_to: Otis.Library.Events.producer}
  end

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end

  # Allows tests to wait for successful removal of the handler
  #
  #    on_exit fn ->
  #      Otis.Events.remove_handler(MessagingHandler, self())
  #      assert_receive :remove_messaging_handler, 200
  #    end

  def terminate(pid, _parent)
  when is_pid(pid) do
    send(pid, :remove_messaging_handler)
    :ok
  end
end

Ecto.Migrator.run(Peel.Repo, Path.join([__DIR__, "../priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Peel.Repo)

{:ok, _} = Application.ensure_all_started(:otis)
[otis] = Mix.Dep.loaded_by_name([:otis], [])
Ecto.Migrator.run(Otis.State.Repo, Path.join([otis.opts[:dest], "priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Otis.State.Repo)

ExUnit.start()
