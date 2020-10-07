defmodule Otis.Library.UPNP.Source do
  defstruct [:id]

  @id_join "/"

  def id(device_id, item_id) do
    [device_id, item_id]
    |> Enum.map(&encode_id/1)
    |> Enum.join(@id_join)
  end

  def split_id(id) do
    id |> String.split(@id_join) |> Enum.map(&decode_id/1)
  end

  def decode_id(id) do
    id |> URI.decode()
  end

  def encode_id(id) do
    id |> URI.encode(&URI.char_unreserved?/1)
  end
end

defimpl Otis.Library.Source.Origin, for: Otis.Library.UPNP.Source do
  alias Otis.Library.UPNP
  alias UPNP.Source
  alias UPNP.Item

  def load!(%Source{id: id}) do
    [device_id, item_id] = Source.split_id(id)
    device = UPNP.Discovery.lookup!(device_id)
    {:ok, %Item{} = item} = device |> UPNP.Client.ContentDirectory.retreive(item_id)
    item
  end
end
