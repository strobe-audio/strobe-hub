defmodule HLS.Reader.Http do
  require Logger
  alias   HTTPoison.Response

  defstruct []

  def read!(url) do
    # want to raise an error if we get an error, but if we get an error we want
    # delay a bit
    {:ok, response} = read(url)
    {:ok, response.body}
  end

  def read_with_expiry!(url) do
    # want to raise an error if we get an error, but if we get an error we want
    # delay a bit
    {:ok, response} = read(url)
    {:ok, response.body, expiry(response.headers)}
  end

  defp read(url, tries \\ 5, delay \\ 50)
  defp read(url, tries, delay) do
    HTTPoison.get(url, [], [])
    |> validate_response
    |> delay_errors(url)
    |> retry(url, tries - 1, delay * 2)
  end

  defp validate_response({:error, _} = error) do
    error
  end
  defp validate_response({:ok, %Response{status_code: 200} = response}) do
    {:ok, response}
  end
  defp validate_response({:ok, response}) do
    Logger.warn "Invalid response #{ inspect response }"
    {:error, response}
  end

  defp delay_errors({:ok, _} = response, _url) do
    response
  end
  defp delay_errors(response, url) do
    Logger.warn "Error retreiving #{url} #{inspect response}"
    # wait a bit before our supervisor restarts us
    Process.sleep(100)
    response
  end

  defp retry({:ok, _} = response, _url, _tries, _delay) do
    response
  end
  defp retry({:error, error} = response, url, 0, _delay) do
    Logger.warn "Read failed #{url} #{ inspect error }"
    response
  end
  defp retry({:error, _}, url, tries, delay) do
    Logger.warn "Retrying #{url} attempt #{tries}"
    read(url, tries, delay)
  end

  @cache_control "Cache-Control"

  defp expiry(headers) do
    headers
    |> cache_control_header
    |> read_expiry
  end

  defp read_expiry(nil) do
    nil
  end
  defp read_expiry(header) when is_binary(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> extract_expiry
  end

  defp cache_control_header(headers) do
    case Enum.find(headers, fn({k, _}) -> k == @cache_control end) do
      {@cache_control, value} ->
        value
      _ ->
        nil
    end
  end

  defp extract_expiry([]) do
    nil
  end
  defp extract_expiry(["max-age=" <> age | _parts]) do
    age |> String.trim() |> String.to_integer
  end
  defp extract_expiry([_ | parts]) do
    extract_expiry(parts)
  end
end

defimpl HLS.Reader, for: HLS.Reader.Http do
  def read!(_reader, url) do
    {:ok, body} = HLS.Reader.Http.read!(url)
    body
  end
  def read_with_expiry!(_reader, url) do
    {:ok, body, expiry} = HLS.Reader.Http.read_with_expiry!(url)
    {body, expiry}
  end
end