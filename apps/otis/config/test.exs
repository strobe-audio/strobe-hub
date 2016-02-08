use Mix.Config

config :logger, :console,
  level: :error,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [],
  colors: [info: :green]

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox
