defmodule Elvis.ManifestController do
  use Elvis.Web, :controller

  def manifest(conn, _params) do
    conn
    |> put_resp_content_type("text/cache-manifest")
    |> put_layout("manifest.txt")
    |> render("manifest.txt")
  end
end
