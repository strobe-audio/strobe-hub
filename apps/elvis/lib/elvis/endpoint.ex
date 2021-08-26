defmodule Elvis.Endpoint do
  use Phoenix.Endpoint, otp_app: :elvis

  socket "/controller", Elvis.ControllerSocket, websocket: true

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :elvis,
    gzip: true,
    only: ~w(css fonts images js svg favicon.ico robots.txt)
  )

  plug(Plug.Static,
    at: Otis.Media.at(),
    from: Otis.Media.from(),
    gzip: false,
    cache_control_for_etags: "public, max-age=31536000"
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # plug Plug.Session,
  #   store: :cookie,
  #   key: "_elvis_key",
  #   signing_salt: "iekhHByu"

  plug(Elvis.Router)
end
