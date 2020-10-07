defmodule TestEventHandler do
  use GenStage

  def attach(producer \\ Strobe.Events.producer()) do
    {:ok, _pid} = start_link(self(), producer)
    :ok
  end

  def start_link(parent, producer) do
    GenStage.start_link(__MODULE__, {parent, producer})
  end

  def init({parent, producer}) do
    {:consumer, parent, subscribe_to: List.wrap(producer)}
  end

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end

  def handle_events([event | events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end
end

Ecto.Migrator.run(Peel.Repo, Path.join([__DIR__, "../priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Peel.Repo)

ExUnit.start(assert_receive_timeout: 500)
