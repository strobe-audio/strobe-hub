# defmodule Otis.Source do
#
# end
defmodule Otis.Source do
  # @doc "Opens the source for reading"
  # def open(source)
  #
  # @doc "Cleans up any resources once the music is over"
  # def close(source)

  @doc "Gives the next chunk of datea from the source"
  def chunk(pid) do
    GenServer.call(pid, :chunk)
  end

  @doc """
  Returns info about the current source. This will vary according to the source
  type but should conform to some kind of as-yet-determined api.
  """
  def info(pid) do
    GenServer.call(pid, :source_info)
  end
end
