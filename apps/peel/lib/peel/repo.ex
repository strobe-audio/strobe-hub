
defmodule Peel.Repo do
  use Ecto.Repo, otp_app: :peel,
    adapter: Sqlite.Ecto
end
