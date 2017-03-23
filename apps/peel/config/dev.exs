use Mix.Config

root_dir = Path.expand("#{__DIR__}/../../..")
state_dir = Path.join([root_dir, "_state", to_string(Mix.env)])

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: Path.join([state_dir, "peel.dev.sqlite3"])

