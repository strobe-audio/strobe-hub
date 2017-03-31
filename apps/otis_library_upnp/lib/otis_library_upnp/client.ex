defmodule Otis.Library.UPNP.Client do
  @s_ns %{"xmlns:s" => "http://schemas.xmlsoap.org/soap/envelope/"}
  @s_envelope "s:Envelope"
  @s_body "s:Body"

  def envelope(contents \\ []) do
    {@s_envelope, @s_ns, body(contents)} |> XmlBuilder.generate
  end

  def body(contents) do
    [{@s_body, %{}, contents}]
  end

  def headers(action) do
    [{"Content-Type", "text/xml; encoding=utf-8"}, {"SOAPAction", action}]
  end
end
