defmodule Otis.Library.UPNP.Client do
  @s_ns %{"xmlns:s" => "http://schemas.xmlsoap.org/soap/envelope/"}
  @s_envelope "s:Envelope"
  @s_body "s:Body"

  def envelope(contents \\ [], action) do
    {@s_envelope, @s_ns, body(contents, action)} |> XmlBuilder.generate()
  end

  def body(contents, {urn, action}) do
    [{@s_body, %{}, [{"upnp:#{action}", %{"xmlns:upnp" => urn}, contents}]}]
  end

  def headers({urn, action}) do
    [{"Content-Type", "text/xml; encoding=utf-8"}, {"SOAPAction", "#{urn}##{action}"}]
  end
end
