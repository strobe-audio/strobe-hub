defmodule HLS.Reader.Http do
  defstruct []

  def read(url) do
    # want to raise an error if we get an error, but if we get an error we want
    # delay a bit
    {:ok, _body, _expiry} =
      case HTTPoison.get(url, [], []) do
        {:ok, response} ->
          {:ok, response.body, expiry(response.headers)}
        {:error, error} ->
          # wait a bit before our supervisor restarts us
          Process.sleep(100)
          {:error, error}
      end
  end

  @cache_control "Cache-Control"

  defp expiry(headers) do
    headers
    |> cache_control_header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> parse_cache_control
  end

  defp cache_control_header(headers) do
    {@cache_control, value} =
      Enum.find(headers, fn({k, _}) -> k == @cache_control end)
    value
  end

  defp parse_cache_control([]) do
    nil
  end
  defp parse_cache_control(["max-age=" <> age | _parts]) do
    age |> String.trim() |> String.to_integer
  end
  defp parse_cache_control([_ | parts]) do
    parse_cache_control(parts)
  end
end

defimpl HLS.Reader, for: HLS.Reader.Http do
  def read!(_reader, url) do
    {:ok, body, expiry} = HLS.Reader.Http.read(url)
    {body, expiry}
  end
end