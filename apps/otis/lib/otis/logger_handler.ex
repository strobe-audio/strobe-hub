defmodule Otis.LoggerHandler do
  use     GenEvent
  require Logger

  def handle_event(event, id) do
    Logger.info "EVENT: #{ inspect id } -> #{ inspect event }"
    {:ok, id}
  end
end
