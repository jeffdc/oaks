defmodule Oaks.Sources.SpeciesSource do
  @moduledoc """
  Ecto schema for the species_sources junction table.

  Links a species to a source with per-source descriptive data
  (morphology, range, local names, etc.).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Oaks.Sources.Source
  alias Oaks.Species.Species

  @required_fields [:species_id, :source_id]

  @type t :: %__MODULE__{}

  schema "species_sources" do
    field :local_names, :string
    field :range, :string
    field :growth_habit, :string
    field :leaves, :string
    field :flowers, :string
    field :fruits, :string
    field :bark, :string
    field :twigs, :string
    field :buds, :string
    field :hardiness_habitat, :string
    field :miscellaneous, :string
    field :url, :string
    field :is_preferred, :boolean, default: false

    belongs_to :species, Species
    belongs_to :source, Source
  end

  def changeset(species_source, attrs) do
    species_source
    |> cast(attrs, [
      :species_id,
      :source_id,
      :local_names,
      :range,
      :growth_habit,
      :leaves,
      :flowers,
      :fruits,
      :bark,
      :twigs,
      :buds,
      :hardiness_habitat,
      :miscellaneous,
      :url,
      :is_preferred
    ])
    |> validate_required(@required_fields)
    |> validate_length(:range, max: 5000)
    |> validate_length(:growth_habit, max: 5000)
    |> validate_length(:leaves, max: 8000)
    |> validate_length(:flowers, max: 3000)
    |> validate_length(:fruits, max: 5000)
    |> validate_length(:bark, max: 3000)
    |> validate_length(:twigs, max: 3000)
    |> validate_length(:buds, max: 3000)
    |> validate_length(:hardiness_habitat, max: 5000)
    |> validate_length(:miscellaneous, max: 3000)
    |> validate_length(:url, max: 1000)
    |> foreign_key_constraint(:species_id)
    |> foreign_key_constraint(:source_id)
    |> unique_constraint([:species_id, :source_id])
  end
end
