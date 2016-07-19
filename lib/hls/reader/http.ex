defmodule HLS.Reader.Http do
  defstruct []

  def read(_url, 0, _delay) do
    {:error, :http}
  end

  def read(url, attempts, delay) do
    try do
      %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url, [], params: [{"t", now()}])
      {:ok, body}
    catch
:closed, _ ->
      Process.sleep(delay)
      read(url, attempts - 1, delay * 2)
    end
  end

  defp now, do: :os.system_time(:seconds)
end

defimpl HLS.Reader, for: HLS.Reader.Http do
  def read!(_reader, url) do
    {:ok, body} = HLS.Reader.Http.read(url, 5, 100)
    body
  end
end
