defmodule Oaks.Import.AppliedImport do
  @moduledoc """
  A row in the ledger of applied imports (`applied_imports`): the SHA-256 of
  an applied request body and the producer's optional `import_id`.
  `Oaks.Import` writes one in the transaction that applies an import, and
  looks them up so that re-sending an applied import changes nothing.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          body_sha256: binary() | nil,
          import_id: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "applied_imports" do
    field :body_sha256, :binary
    field :import_id, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
