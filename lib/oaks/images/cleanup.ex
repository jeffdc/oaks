defmodule Oaks.Images.Cleanup do
  @moduledoc """
  Stored files to remove: every path of the attempts in `attempt_ids`,
  recorded in the same transaction that stopped needing them (a photo or
  species deleted, an import failed or retried).
  It keeps no foreign keys, so it outlives the image, species and attempts.

  `deleting` until every path is deleted, then `invalidating` until the CDN
  has completed `invalidation_id`, then `done`. Each step is safe to repeat.
  `Oaks.Images.CleanupWorker` does the work, waiting while any of the
  attempts is still leased to a worker.
  """
  use Ecto.Schema

  @reasons ~w(photo_deleted species_deleted import_failed)

  @type t :: %__MODULE__{
          id: integer() | nil,
          paths: [String.t()],
          attempt_ids: [integer()],
          reason: String.t() | nil,
          image_id: integer() | nil,
          species_id: integer() | nil,
          state: String.t(),
          invalidation_id: String.t() | nil,
          tries: non_neg_integer(),
          last_error: String.t() | nil,
          completed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "image_cleanups" do
    field :paths, {:array, :string}, default: []
    field :attempt_ids, {:array, :integer}, default: []
    field :reason, :string
    field :image_id, :integer
    field :species_id, :integer
    field :state, :string, default: "deleting"
    field :invalidation_id, :string
    field :tries, :integer, default: 0
    field :last_error, :string
    field :completed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Why a cleanup can be recorded."
  @spec reasons() :: [String.t()]
  def reasons, do: @reasons
end
