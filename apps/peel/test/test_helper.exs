Ecto.Migrator.run(Peel.Repo, Path.join([__DIR__, "../priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Peel.Repo)
ExUnit.start()
