defmodule OakCompendium.Species.Species do
  @moduledoc """
  Ecto schema for the species table.

  Represents an oak species (or hybrid) in the Quercus genus.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias OakCompendium.Sources.SpeciesSource

  @required_fields [:scientific_name, :is_hybrid]

  @valid_conservation_statuses ~w(EX EW CR EN VU NT LC DD NE)

  schema "species" do
    field :scientific_name, :string
    field :author, :string
    field :is_hybrid, :boolean, default: false
    field :conservation_status, :string
    field :subgenus, :string
    field :section, :string
    field :subsection, :string
    field :complex, :string
    field :parent1, :string
    field :parent2, :string
    field :hybrids, :string
    field :closely_related_to, :string
    field :subspecies_varieties, :string
    field :synonyms, :string
    field :external_links, :string

    has_many :species_sources, SpeciesSource
  end

  def changeset(species, attrs) do
    species
    |> cast(attrs, [
      :scientific_name,
      :author,
      :is_hybrid,
      :conservation_status,
      :subgenus,
      :section,
      :subsection,
      :complex,
      :parent1,
      :parent2,
      :hybrids,
      :closely_related_to,
      :subspecies_varieties,
      :synonyms,
      :external_links
    ])
    |> validate_required(@required_fields)
    |> validate_length(:scientific_name, min: 2, max: 100)
    |> validate_inclusion(:conservation_status, @valid_conservation_statuses)
    |> unique_constraint(:scientific_name)
  end
end
