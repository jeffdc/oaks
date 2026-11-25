defmodule Oaks.INaturalist.Observation do
  @moduledoc """
  An iNaturalist observation, as `Oaks.INaturalist.fetch_observation/1`
  parses it: who observed it, of what, when (`observed_on`) and where (the
  observer's `place_guess`), its `quality_grade` ("research", "needs_id" or
  "casual"), and its photos.
  """

  alias Oaks.INaturalist.Photo

  @enforce_keys [:id, :url, :photos]
  defstruct [
    :id,
    :taxon_id,
    :taxon_name,
    :observer_login,
    :observer_name,
    :url,
    :observed_on,
    :place_guess,
    :quality_grade,
    photos: []
  ]

  @type t :: %__MODULE__{
          id: pos_integer(),
          taxon_id: integer() | nil,
          taxon_name: String.t() | nil,
          observer_login: String.t() | nil,
          observer_name: String.t() | nil,
          url: String.t(),
          observed_on: Date.t() | nil,
          place_guess: String.t() | nil,
          quality_grade: String.t() | nil,
          photos: [Photo.t()]
        }
end
