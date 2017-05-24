use Mix.Config

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: "/var/db/peep/peel.dev.sqlite3"

config :peel, Peel.Collection,
  dav_root: "/mnt/Music/strobe/peel/dav",
  collection_root: "/mnt/Music/strobe/peel/collections",
  port: 8080
