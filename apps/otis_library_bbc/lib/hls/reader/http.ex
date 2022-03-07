defmodule HLS.Reader.Http do
  require Logger

  alias Finch.Response

  defstruct []

  @cache_control_header "Cache-Control"

  def read(url) do
    case _read(url) do
      {:ok, response} ->
        {:ok, response.body, response.headers}

      {:error, response} ->
        {:error, response}
    end
  end

  def expiry(headers, default \\ 3) do
    headers
    |> cache_control_header
    |> read_expiry(default)
  end

  defp _read(url, tries \\ 5, delay \\ 50)

  defp _read(url, tries, delay) do
    Logger.debug(fn -> ["GET ", url, " try: ", to_string(tries)] end)

    Finch.build(:get, url)
    |> Finch.request(BBC.Finch)
    |> validate_response()
    |> delay_errors(url)
    |> retry(url, tries - 1, delay * 2)
  end

  defp validate_response({:error, _} = error) do
    error
  end

  defp validate_response({:ok, %Response{status: 200} = response}) do
    {:ok, response}
  end

  defp validate_response({:ok, response}) do
    Logger.warn("Invalid response #{inspect(response)}")
    {:error, response}
  end

  defp delay_errors({:ok, _} = response, _url) do
    response
  end

  defp delay_errors(response, url) do
    Logger.warn("Error retreiving #{url} #{inspect(response)}")
    # wait a bit before our supervisor restarts us
    Process.sleep(100)
    response
  end

  defp retry({:ok, _} = response, _url, _tries, _delay) do
    response
  end

  defp retry({:error, error} = response, url, 0, _delay) do
    Logger.error("Read failed #{url} #{inspect(error)}")
    response
  end

  defp retry({:error, _}, url, tries, delay) do
    Logger.warn("Retrying #{url}; attempts remaining: #{tries}")
    _read(url, tries, delay)
  end

  defp read_expiry(nil, default) do
    default
  end

  defp read_expiry(header, default) when is_binary(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> extract_expiry(default)
  end

  defp cache_control_header(headers) do
    case Enum.find(headers, fn {k, _} -> k == @cache_control_header end) do
      {@cache_control_header, value} ->
        value

      _ ->
        nil
    end
  end

  defp extract_expiry([], default) do
    default
  end

  defp extract_expiry(["max-age=" <> age | _parts], _default) do
    age |> String.trim() |> String.to_integer()
  end

  defp extract_expiry([_ | parts], default) do
    extract_expiry(parts, default)
  end
end

defimpl HLS.Reader, for: HLS.Reader.Http do
  def read(_reader, "file://" <> path) do
    {:ok, File.read!(path), []}
  end

  def read(_reader, url) do
    HLS.Reader.Http.read(url)
  end
end
