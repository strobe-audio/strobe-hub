defmodule Otis.Registry do
  @moduledoc """
  Provides some simple macros to make working with the shared process registry
  easier.
  """

  @doc """
  Maps the given id to a `{:via, Registry, {__MODULE__, id}}` tuple suitable
  for passing to GenServer calls.
  """
  @spec via(atom | binary) :: tuple
  defmacro via(id) do
    quote do
      {:via, Registry, {Otis.Registry, {__MODULE__, unquote(id)}}}
    end
  end

  @doc """
  Lookup the process registered as `{__MODULE__, id}`.
  """
  @spec whereis(atom | binary) :: pid | nil
  defmacro whereis(id) do
    quote do
      GenServer.whereis({:via, Registry, {Otis.Registry, {__MODULE__, unquote(id)}}})
    end
  end
end
