defmodule Otis.Library.UPNP.ServerTest do
  use ExUnit.Case

  alias Otis.Library.UPNP.Server
  alias Otis.Library.UPNP.Server.Service

  test "server info XML parsing" do
    doc = """
      <root xmlns="urn:schemas-upnp-org:device-1-0">
      <specVersion><major>1</major><minor>0</minor></specVersion>
        <device>
          <friendlyName>some server</friendlyName>
          <serviceList>
            <service>
              <serviceType>urn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
              <serviceId>urn:upnp-org:serviceId:ContentDirectory</serviceId>
              <controlURL>/ctl/ContentDir</controlURL>
              <eventSubURL>/evt/ContentDir</eventSubURL>
              <SCPDURL>/ContentDir.xml</SCPDURL>
            </service>
            <service>
              <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
              <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
              <controlURL>/ctl/ConnectionMgr</controlURL>
              <eventSubURL>/evt/ConnectionMgr</eventSubURL>
              <SCPDURL>/ConnectionMgr.xml</SCPDURL>
            </service>
          </serviceList>
        </device>
      </root>
    """

    assert Server.parse(doc, "uuid:4d696e69-444c-164e-9d41-001c42fc0db6", "http://192.168.1.99:8347/sdfoij/") == %Server{
      id: "uuid:4d696e69-444c-164e-9d41-001c42fc0db6",
      name: "some server",
      location: "http://192.168.1.99:8347/sdfoij/",
      directory: %Service{
        type: "urn:schemas-upnp-org:service:ContentDirectory:1",
        id: "urn:upnp-org:serviceId:ContentDirectory",
        control_url: "http://192.168.1.99:8347/ctl/ContentDir",
        event_sub_url: "http://192.168.1.99:8347/evt/ContentDir",
        scpd_url: "http://192.168.1.99:8347/ContentDir.xml",
      },
    }
  end
end
