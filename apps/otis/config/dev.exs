use Mix.Config

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: Path.join(project_root_path, "_state/otis.dev.sqlite3")
