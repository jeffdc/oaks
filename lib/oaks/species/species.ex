defmodule Oaks.Species.Species do
  @moduledoc """
  Ecto schema for the species table.

  Represents an oak species (or hybrid) in the Quercus genus.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Oaks.JsonList
  alias Oaks.Sources.SpeciesSource

  @required_fields [:scientific_name, :is_hybrid]

  @valid_conservation_statuses ~w(EX EW CR EN VU NT LC DD NE)

  @type t :: %__MODULE__{}

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
    |> JsonList.cast(:hybrids)
    |> JsonList.cast(:closely_related_to)
    |> JsonList.cast(:subspecies_varieties)
    |> JsonList.cast(:synonyms, allow_objects: true)
    |> validate_required(@required_fields)
    |> validate_length(:scientific_name, min: 2, max: 100)
    |> validate_inclusion(:conservation_status, @valid_conservation_statuses)
    |> validate_hybrid_flag()
    |> unique_constraint(:scientific_name)
  end

  # Pages decide whether to show the hybrid sign from the name, so a name
  # containing × must also be flagged as a hybrid.
  defp validate_hybrid_flag(changeset) do
    name = get_field(changeset, :scientific_name) || ""

    if String.contains?(name, "×") and get_field(changeset, :is_hybrid) != true do
      add_error(changeset, :is_hybrid, "must be checked for names containing ×")
    else
      changeset
    end
  end
end
