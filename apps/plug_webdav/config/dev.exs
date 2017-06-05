use Mix.Config

config :plug_webdav, Plug.WebDav.Handler, [
  port: 5555,
  root: "/tmp/plug-webdav",
]
