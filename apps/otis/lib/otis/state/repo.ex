
defmodule Otis.State.Repo do
  use Ecto.Repo,
    otp_app: :otis,
    adapter: Sqlite.Ecto
end
