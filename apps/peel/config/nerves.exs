use Mix.Config

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: "/state/db/current/peel.sqlite"

config :peel, Peel.Webdav,
  root: "/_state/data/peel",
  port: 8080
