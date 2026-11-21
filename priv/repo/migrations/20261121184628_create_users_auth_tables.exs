defmodule Oaks.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  # Login for editors (item 0249): users with a password and a TOTP second
  # factor, their hashed session and setup tokens, and hashed single-use
  # recovery codes. See Oaks.Accounts.
  def change do
    create table(:users) do
      add :email, :string, null: false, collate: :nocase
      # Both stay null until the user finishes setup from a setup link.
      add :hashed_password, :string
      # Encrypted with the login encryption key (Oaks.Accounts.SecretBox).
      add :totp_secret, :binary
      add :totp_last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # SHA-256 of the token; the token itself is only in the user's cookie or link.
      add :token, :binary, null: false
      add :context, :string, null: false
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:users_recovery_codes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :hashed_code, :binary, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_recovery_codes, [:user_id])
    create unique_index(:users_recovery_codes, [:hashed_code])
  end
end
