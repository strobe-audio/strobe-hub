defmodule Peel.Repo.Migrations.JournalModeWal do
  use Ecto.Migration
  # Need to disable the default transaction wrapping or the pragma setting
  # doesn't work
  @disable_ddl_transaction true

  def change do
    # Use WAL to enable simultaneous reads & writes
    # http://www.sqlite.org/wal.html
    execute "PRAGMA journal_mode=WAL"
  end
end

