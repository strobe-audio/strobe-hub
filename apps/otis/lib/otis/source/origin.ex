defprotocol Otis.Source.Origin do
  @doc "Loads the source instance given a record with a valid id"
  def load!(source)
end
