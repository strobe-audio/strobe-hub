use Mix.Config

config :plug_webdav, Plug.WebDAV.Handler,
  port: 5555,
  root: "/tmp/plug-webdav"
