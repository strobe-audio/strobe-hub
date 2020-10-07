defmodule Otis.Library.UPNP.ClientTest do
  use ExUnit.Case

  setup do
    server = %Otis.Library.UPNP.Server{
      id: "uuid:4d696e69-444c-164e-9d41-001c42fc0db6::urn:schemas-upnp-org:device:MediaServer:1",
      location: "http://192.168.1.92:8200/rootDesc.xml",
      name: "archibald: root",
      directory: %Otis.Library.UPNP.Server.Service{
        control_url: "http://192.168.1.92:8200/ctl/ContentDir",
        event_sub_url: "http://192.168.1.92:8200/evt/ContentDir",
        id: "urn:upnp-org:serviceId:ContentDirectory",
        scpd_url: "http://192.168.1.92:8200/ContentDir.xml",
        type: "urn:schemas-upnp-org:service:ContentDirectory:1"
      }
    }

    {:ok, server: server}
  end

  test "parsing UTF responses", context do
    {:ok, xml} = File.read(Path.join([__DIR__, "response.xml"]))

    {:ok, %{containers: containers, items: []}} =
      Otis.Library.UPNP.Client.ContentDirectory.parse_browse_response(xml, context.server)

    assert length(containers) == 4

    assert Enum.map(containers, fn %{title: title} -> title end) == [
             "Something",
             "Air",
             "Al Wilson",
             "Eugène Faveau"
           ]
  end
end
