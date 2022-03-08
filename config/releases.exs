import Config

port = System.get_env("PORT", "4000")

config :elvis, Elvis.Endpoint, http: [port: port]

# db_root = System.get_env("STROBE_DB_PATH", "/var/db/strobe") |> IO.inspect(label: :db_root)

# config :otis, Otis.State.Repo,
#   adapter: Sqlite.Ecto2,
#   database: Path.join(db_root, "otis.prod.sqlite3")

# config :otis, Otis.Media,
#   root: Path.join(db_root, "fs"),
#   at: "/fs"

# config :peel, Peel.Repo,
#   adapter: Sqlite.Ecto2,
#   database: Path.join(db_root, "peel.prod.sqlite3")

# config :peel, Peel.Collection,
#   root: "/mnt/Music/strobe/peel/collections",
#   port: 8080
