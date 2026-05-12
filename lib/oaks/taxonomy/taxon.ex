defmodule Oaks.Taxonomy.Taxon do
  @moduledoc """
  Ecto schema for the taxa table.

  Represents a taxonomic rank (subgenus, section, subsection, or complex)
  in the Quercus hierarchy. The `parent` field is a text reference to the
  parent taxon's name, not a foreign key.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_levels ~w(subgenus section subsection complex)
  @required_fields [:name, :level]

  @type t :: %__MODULE__{}

  schema "taxa" do
    field :name, :string
    field :level, :string
    field :parent, :string
    field :author, :string
    field :content, :string
    field :content_updated_at, :string
    field :links, :string

    # Populated by list_taxa_with_counts/1 via select_merge
    field :species_count, :integer, virtual: true, default: 0
  end

  def changeset(taxon, attrs) do
    taxon
    |> cast(attrs, [:name, :level, :parent, :author, :content, :content_updated_at, :links])
    |> validate_required(@required_fields)
    |> validate_inclusion(:level, @valid_levels)
    |> unique_constraint([:name, :level])
  end
end
