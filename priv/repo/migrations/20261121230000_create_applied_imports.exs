defmodule Oaks.Repo.Migrations.CreateAppliedImports do
  use Ecto.Migration

  # The ledger of applied bulk imports (item f8f5): one row per import the
  # private API's import endpoint applied, so re-sending one is a no-op. See
  # Oaks.Import.AppliedImport.
  def change do
    create table(:applied_imports) do
      # SHA-256 of the request body's raw bytes.
      add :body_sha256, :binary, null: false
      # The producer's optional name for the import.
      add :import_id, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:applied_imports, [:body_sha256])
    # SQLite lets many rows have a NULL import_id under a unique index.
    create unique_index(:applied_imports, [:import_id])
  end
end
