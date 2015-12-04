
defmodule Otis.State.Repo do
  use Behaviour
  defcallback create_zone
  defcallback destroy_zone
end

defmodule Otis.State.Repo.Sqlite do
  @behaviour Otis.State.Repo
  # actually writes to the db
end

defmodule Otis.State.Repo.Test do
  @behaviour Otis.State.Repo
  # just records the functions called
end

defmodule Otis.State.Supervisor do
  def start_link(repo) do

  end
end

defmodule Otis.State.Zone do

  defstruct id: :default_zone, name: "Default Zone", receiver_ids: []

  def create(name)

  def destroy(zone)
  def rename(zone)

  # you can only add -- receivers are just moved around
  # maps to a detach_receiver, attach_receiver pair
  def add_receiver(zone, receiver)

  def volume(zone, volume)
  def mute(zone)

  def replace_source_list(zone, source_list)
  def insert_source(zone, source, position)
  def remove_source(zone, source)
  def position_source(zone, source, position)

  def play_pause(zone)
  def skip(zone, source) #
  def scrub(zone, time) # time? what is the param here?


end
