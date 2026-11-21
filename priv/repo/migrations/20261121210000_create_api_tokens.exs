defmodule Oaks.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  # Agent tokens for the private API (item fbd0): issued and revoked by an
  # editor on the settings page, each with scopes and an expiry. See
  # Oaks.Accounts.ApiToken.
  def change do
    create table(:api_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      # SHA-256 of the token; the token itself is shown once, when issued.
      add :hashed_token, :binary, null: false
      # A JSON array of scope names.
      add :scopes, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:api_tokens, [:user_id])
    create unique_index(:api_tokens, [:hashed_token])
  end
end
