defmodule Oaks.Species.Species do
  @moduledoc """
  Ecto schema for the species table.

  Represents an oak species (or hybrid) in the Quercus genus. Links to other
  rows are keys: `taxon_id` is the lowest taxon the species sits in, and a
  hybrid's `parent1_id` and `parent2_id` point at its parents' rows. The
  parent names the editor typed are virtual fields, resolved to keys by
  `Oaks.Species`.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Oaks.ChangesetHelpers

  alias Oaks.JsonList
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Taxonomy.Taxon

  @required_fields [:scientific_name, :is_hybrid]

  @valid_conservation_statuses ~w(EX EW CR EN VU NT LC DD NE)

  @type t :: %__MODULE__{}

  schema "species" do
    field :scientific_name, :string
    field :author, :string
    field :is_hybrid, :boolean, default: false
    field :conservation_status, :string
    field :synonyms, :string
    field :external_links, :string

    belongs_to :taxon, Taxon
    belongs_to :parent1, __MODULE__, foreign_key: :parent1_id
    belongs_to :parent2, __MODULE__, foreign_key: :parent2_id

    # The parent names as typed in the species form, resolved to parent1_id
    # and parent2_id by Oaks.Species.
    field :parent1_name, :string, virtual: true
    field :parent2_name, :string, virtual: true

    has_many :species_sources, SpeciesSource
  end

  def changeset(species, attrs) do
    species
    |> cast(attrs, [
      :scientific_name,
      :author,
      :is_hybrid,
      :conservation_status,
      :synonyms,
      :external_links,
      :taxon_id,
      :parent1_id,
      :parent2_id,
      :parent1_name,
      :parent2_name
    ])
    |> trim_strings()
    |> JsonList.cast(:synonyms, allow_objects: true)
    |> validate_required(@required_fields)
    |> validate_length(:scientific_name, min: 2, max: 100)
    |> validate_inclusion(:conservation_status, @valid_conservation_statuses)
    |> validate_hybrid_flag()
    |> validate_parents()
    |> unique_constraint(:scientific_name)
  end

  @doc """
  Checks a hybrid's parent keys: neither may be the species itself, and the
  two must differ. The errors go on `fields` (the id fields by default; the
  species form passes its name fields, which it resolves to the keys after
  this changeset has run).
  """
  @spec validate_parents(Ecto.Changeset.t(), {atom(), atom()}) :: Ecto.Changeset.t()
  def validate_parents(changeset, {field1, field2} \\ {:parent1_id, :parent2_id}) do
    id = changeset.data.id
    parent1 = get_field(changeset, :parent1_id)
    parent2 = get_field(changeset, :parent2_id)

    changeset
    |> refuse_parent(id != nil and parent1 == id, field1, "can't be the species itself")
    |> refuse_parent(id != nil and parent2 == id, field2, "can't be the species itself")
    |> refuse_parent(
      parent1 != nil and parent1 == parent2,
      field2,
      "must differ from the first parent"
    )
  end

  defp refuse_parent(changeset, true, field, message), do: add_error(changeset, field, message)
  defp refuse_parent(changeset, false, _field, _message), do: changeset

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
