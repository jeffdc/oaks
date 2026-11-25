defmodule Oaks.Images.ImportAttempt do
  @moduledoc """
  One try at storing a photo's files: downloading `photo_url` and storing the
  original at `original_path` and its four variants beside it. Every attempt
  has paths of its own, so cleaning up one can never remove another's files.

  States: `queued` (waiting for a worker), `running` (a worker has claimed
  it), `published`, `failed` (gave up; its files are being cleaned up) and
  `cancelled` (its photo was deleted or merged away; it may not publish or
  write again). `stored_at` is set once all five files are written, so a
  resumed attempt only has to publish. While `lease_until` is in the future
  the worker holding `lease_token` may write, and cleanup of the attempt's
  files waits.
  """
  use Ecto.Schema

  @states ~w(queued running published failed cancelled)

  @type t :: %__MODULE__{
          id: integer() | nil,
          image_id: integer() | nil,
          original_path: String.t() | nil,
          photo_url: String.t() | nil,
          state: String.t(),
          lease_token: String.t() | nil,
          lease_until: DateTime.t() | nil,
          tries: non_neg_integer(),
          stored_at: DateTime.t() | nil,
          last_error: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "image_import_attempts" do
    field :image_id, :integer
    field :original_path, :string
    field :photo_url, :string
    field :state, :string, default: "queued"
    field :lease_token, :string
    field :lease_until, :utc_datetime_usec
    field :tries, :integer, default: 0
    field :stored_at, :utc_datetime_usec
    field :last_error, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc "The states an attempt can be in."
  @spec states() :: [String.t()]
  def states, do: @states
end
