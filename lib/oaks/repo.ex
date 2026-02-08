defmodule Oaks.Repo do
  use Ecto.Repo,
    otp_app: :oaks,
    adapter: Ecto.Adapters.SQLite3
end
