defmodule Elvis.ManifestController do
  use Elvis.Web, :controller

  def manifest(conn, _params) do
    conn
    |> put_resp_content_type("text/cache-manifest")
    |> put_layout("manifest.txt")
    |> render("manifest.txt")
  end

  def manifest_json(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> json(
      %{
        name: "Strobe Audio",
        short_name: "Strobe",
        icons: [
          %{
            src: "/images/touch-icon@2x.png",
            sizes: "128x128",
            type: "image/png"
          },
          %{
            src: "/images/touch-icon@3x.png",
            sizes: "192x192",
            type: "image/png"
          }
        ],
        start_url: "/",
        display: "standalone",
        background_color: "#000000",
        theme_color: "#FF0000"
      }
    )
  end
end
