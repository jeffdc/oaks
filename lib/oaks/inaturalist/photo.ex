defmodule Oaks.INaturalist.Photo do
  @moduledoc """
  A photo of an iNaturalist observation: its iNat ID, the URLs of its
  medium-size thumbnail and its original, and its license, both as iNat's
  code and as the license an image stores (`Oaks.INaturalist.map_license/1`).
  A `needs_permission?` photo (All Rights Reserved, which includes an
  `unrecognized_license?` one) can be imported only with the editor's
  confirmation that its creator has given permission.
  """

  @enforce_keys [:id, :mapped_license]
  defstruct [
    :id,
    :thumbnail_url,
    :original_url,
    :license_code,
    :mapped_license,
    needs_permission?: true,
    unrecognized_license?: false
  ]

  @type t :: %__MODULE__{
          id: pos_integer(),
          thumbnail_url: String.t() | nil,
          original_url: String.t() | nil,
          license_code: String.t() | nil,
          mapped_license: String.t(),
          needs_permission?: boolean(),
          unrecognized_license?: boolean()
        }
end
