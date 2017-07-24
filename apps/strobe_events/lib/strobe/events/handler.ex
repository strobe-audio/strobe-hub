defmodule Strobe.Events.Handler do
  defmacro __using__(opts \\ []) do
    filter_complete? = Keyword.get(opts, :filter_complete, true)
    quote bind_quoted: [filter_complete?: filter_complete?] do
      require Strobe.Events

      def handle_events([], _from, state) do
        {:noreply, [], state}
      end
      if filter_complete? do
        def handle_events([{:__complete__, _event, _handler}|events], from, state) do
          handle_events(events, from, state)
        end
      else
        # Broadcast the :__complete__ event but don't send recursive
        # {:__complete__, {:__complete, ...}} followup
        def handle_events([{:__complete__, _event, _handler} = event|events], from, state) do
          {_, state} = handle_event(event, state)
          handle_events(events, from, state)
        end
      end
      def handle_events([event|events], from, state) do
        state =
          case handle_event(event, state) do
            {:ok, state} ->
              Strobe.Events.complete(event)
              state
            {:incomplete, state} ->
              state
          end
        handle_events(events, from, state)
      end
    end
  end
end
