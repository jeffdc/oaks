defmodule Oaks.Analytics.PageView do
  @moduledoc """
  Ecto schema for page view analytics.

  Stores anonymized page view data for traffic analysis. No personally
  identifiable information is stored — visitors are tracked via a daily-
  rotating SHA256 hash of date + IP + user-agent.

  Schema-aligned with gallformers' `page_views` table for forward
  compatibility, with the addition of `status` (HTTP response code) so the
  dashboard can surface 404s. The `browser` and `device_type` columns are
  present but are NOT populated by the oaks tracking plug and are NOT
  queried by oaks; they exist so future expansion only needs capture
  changes, not migrations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{}

  schema "page_views" do
    field :path, :string
    field :status, :integer
    field :referrer_host, :string
    field :browser, :string
    field :device_type, :string
    field :visitor_hash, :string

    timestamps(updated_at: false)
  end

  @required_fields [:path, :status, :visitor_hash]
  @optional_fields [:referrer_host, :browser, :device_type]

  @doc """
  Builds a changeset for inserting a page view.

  Required: `path`, `status`, `visitor_hash`.
  Optional: `referrer_host`, `browser`, `device_type`.

  Length constraints: `path` ≤ 2000, `referrer_host` / `browser` /
  `device_type` ≤ 255, `visitor_hash` must be exactly 64 chars (SHA256 hex).
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:path, max: 2000)
    |> validate_length(:referrer_host, max: 255)
    |> validate_length(:browser, max: 255)
    |> validate_length(:device_type, max: 255)
    |> validate_length(:visitor_hash, is: 64)
  end
end
