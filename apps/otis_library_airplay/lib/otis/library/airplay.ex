defmodule Otis.Library.Airplay do
  @library_id "bf1fb606-1dfe-11e7-ac0f-002500f418fc"

  def library_id, do: @library_id

  def ids do
    if Otis.Library.Airplay.Shairport.installed? do
      instances = Application.get_env(:otis_library_airplay, :inputs) || 0
      Enum.take(1..instances, instances)
    else
      []
    end
  end

  def inputs do
    Enum.map(ids(), &input/1)
  end

  def input(id) do
    %Otis.Library.Airplay.Input{id: id}
  end

  def producer_id(n) do
    :"otis-library-airport-input-#{n}"
  end
end
