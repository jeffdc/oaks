defmodule Oaks.Taxonomy.Taxon do
  @moduledoc """
  Ecto schema for the taxa table.

  Represents a taxonomic rank (genus, subgenus, section, subsection, or
  complex) in the Quercus hierarchy. `parent_id` points at the rank above;
  only the genus has no parent.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Oaks.ChangesetHelpers

  @valid_levels ~w(genus subgenus section subsection complex)
  @required_fields [:name, :level]

  @type t :: %__MODULE__{}

  schema "taxa" do
    field :name, :string
    field :level, :string
    field :author, :string
    field :content, :string
    field :content_updated_at, :string
    field :links, :string

    belongs_to :parent, __MODULE__, foreign_key: :parent_id

    # Populated by list_taxa_with_counts/1 and get_children/1
    field :species_count, :integer, virtual: true, default: 0
  end

  def changeset(taxon, attrs) do
    taxon
    |> cast(attrs, [:name, :level, :parent_id, :author, :content, :content_updated_at, :links])
    |> trim_strings()
    |> validate_required(@required_fields)
    |> validate_inclusion(:level, @valid_levels)
    |> unique_constraint([:name, :level])
    |> unique_constraint(:level, name: "idx_taxa_genus")
  end
end
