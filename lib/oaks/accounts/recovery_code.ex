defmodule Oaks.Accounts.RecoveryCode do
  @moduledoc """
  A single-use recovery code, stored as a hash
  (`Oaks.Accounts.SecondFactor.hash_recovery_code/1`). It stands in for a
  TOTP code when the authenticator app isn't to hand.
  """
  use Ecto.Schema

  schema "users_recovery_codes" do
    field :hashed_code, :binary, redact: true
    field :used_at, :utc_datetime
    belongs_to :user, Oaks.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
