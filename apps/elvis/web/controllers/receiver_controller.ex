defmodule Elvis.ReceiverController do
  use Elvis.Web, :controller

  plug :put_headers, %{"content-type" => "audio/x-aiff"}

  def receive(conn, %{"id" => id} = _params) do
    Otis.Receivers.start_receiver(id, "Some name", self)
    conn |> send_chunked(200) |> stream
  end

  defp stream(conn) do
    receive do
      {:audio_frame, data} ->
        # send data
        {:ok, conn} = chunk(conn, data)
      _ = msg ->
        # don't know!
        IO.inspect [:message, msg]
    end
    stream(conn)
  end

  def terminate(reason, state) do
    IO.inspect [:receiver_conn, :terminate, reason, state]
    :ok
  end

  defp put_headers(conn, key_values) do
    Enum.reduce key_values, conn, fn {k, v}, conn ->
      Plug.Conn.put_resp_header(conn, k, v)
    end
  end
end
