defmodule Otis.Library.UPNP.Server do
  @directory_service_urn "urn:schemas-upnp-org:service:ContentDirectory:1"

  defstruct [:id, :name, :location, :directory]

  import SweetXml

  defmodule Service do
    defstruct [:id, :type, :scpd_url, :event_sub_url, :control_url]
  end

  def parse(doc, id, location) do
    uri = URI.parse(location)

    data =
      doc
      |> xpath(
        ~x"//root/device",
        name: ~x"./friendlyName/text()"s,
        services: [
          ~x".//serviceList/service"l,
          type: ~x".//serviceType/text()"s,
          id: ~x"./serviceId/text()"s,
          scpd_url: ~x"./SCPDURL/text()"s,
          event_sub_url: ~x"./eventSubURL/text()"s,
          control_url: ~x"./controlURL/text()"s
        ]
      )

    server = %__MODULE__{id: id, name: data.name, location: location}

    directory =
      %Service{}
      |> struct(Enum.find(data.services, fn s -> s.type == @directory_service_urn end))
      |> merge_uris(uri, [:control_url, :event_sub_url, :scpd_url])

    %__MODULE__{server | directory: directory}
  end

  defp merge_uris(struct, base, fields) do
    Enum.reduce(fields, struct, fn field, merged ->
      Map.put(merged, field, URI.merge(base, Map.get(merged, field)) |> URI.to_string())
    end)
  end
end
