use Mix.Config

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: Path.join(project_root_path, "_state/peel.dev.sqlite3")
