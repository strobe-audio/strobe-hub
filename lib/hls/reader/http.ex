defmodule HLS.Reader.Http do
  defstruct []
end

defimpl HLS.Reader, for: HLS.Reader.Http do
  def read!(_reader, url) do
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get! url
    body
  end
end
