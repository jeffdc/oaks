defmodule OakCompendium.Repo do
  use Ecto.Repo,
    otp_app: :oak_compendium,
    adapter: Ecto.Adapters.SQLite3
end
