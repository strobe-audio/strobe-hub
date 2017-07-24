defmodule Otis.Events.Handler do
  defmacro __using__(_opts) do
    quote do
      require Otis.Events

      def handle_events([], _from, state) do
        {:noreply, [], state}
      end
      def handle_events([{:__complete__, _event, _handler}|events], from, state) do
        handle_events(events, from, state)
      end
      def handle_events([event|events], from, state) do
        state =
          case handle_event(event, state) do
            {:ok, state} ->
              Otis.Events.complete(event)
              state
            {:incomplete, state} ->
              state
          end
        handle_events(events, from, state)
      end
    end
  end
end
