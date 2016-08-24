defmodule Otis.Channel.Clock do
  @moduledoc """
  Represents a real-time clock using the system monotonic timer.
  """

  defstruct []

  def new, do: %__MODULE__{}
end

defimpl Otis.Broadcaster.Clock, for: Otis.Channel.Clock do
  require Monotonic

  def time(_clock), do: Monotonic.microseconds
end

