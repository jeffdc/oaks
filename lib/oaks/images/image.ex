defmodule Oaks.Images.Image do
  @moduledoc """
  A species photo, imported from an iNaturalist observation.

  A photo is `pending` while an import attempt stores its files, `ready`
  once its original and all four variants are stored (only ready photos are
  public), and `failed` when its last attempt gave up; an editor can retry
  it. `path` is the published original's (`Oaks.Storage.Images`), nil until
  ready; `current_attempt_id` names the one attempt allowed to publish it.

  Attribution (`creator`, `license`, `licenselink`, `sourcelink`) comes from
  the observation the server fetched, and `uploader` and `lastchangedby`
  from the signed-in editor; none is cast from user input.
  """
  use Ecto.Schema

  alias Oaks.Storage.Images, as: ImageStorage

  @statuses ~w(pending ready failed)

  @type status :: String.t()

  @type t :: %__MODULE__{
          id: integer() | nil,
          species_id: integer() | nil,
          path: String.t() | nil,
          sort_order: integer() | nil,
          caption: String.t() | nil,
          creator: String.t() | nil,
          license: String.t() | nil,
          licenselink: String.t() | nil,
          sourcelink: String.t() | nil,
          inat_observation_id: integer() | nil,
          inat_photo_id: integer() | nil,
          uploader: String.t() | nil,
          lastchangedby: String.t() | nil,
          status: status(),
          last_error: String.t() | nil,
          current_attempt_id: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "images" do
    field :species_id, :integer
    field :path, :string
    field :sort_order, :integer
    field :caption, :string
    field :creator, :string
    field :license, :string
    field :licenselink, :string
    field :sourcelink, :string
    field :inat_observation_id, :integer
    field :inat_photo_id, :integer
    field :uploader, :string
    field :lastchangedby, :string
    field :status, :string, default: "pending"
    field :last_error, :string
    field :current_attempt_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc "The statuses a photo can have."
  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc "The public URL of one size of a ready photo (nil for any other)."
  @spec url(t(), ImageStorage.size()) :: String.t() | nil
  def url(image, size \\ :original)

  def url(%__MODULE__{status: "ready", path: path}, size) when is_binary(path),
    do: ImageStorage.variant_url(path, size)

  def url(%__MODULE__{}, _size), do: nil
end
