defmodule Oaks.Sources.Source do
  @moduledoc """
  Ecto schema for the sources table.

  Represents a data source (website, book, personal observation, etc.)
  that provides information about oak species.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Oaks.Sources.SpeciesSource

  @required_fields [:source_type, :name]

  schema "sources" do
    field :source_type, :string
    field :name, :string
    field :description, :string
    field :author, :string
    field :year, :integer
    field :url, :string
    field :isbn, :string
    field :doi, :string
    field :notes, :string
    field :license, :string
    field :license_url, :string

    has_many :species_sources, SpeciesSource
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [
      :source_type,
      :name,
      :description,
      :author,
      :year,
      :url,
      :isbn,
      :doi,
      :notes,
      :license,
      :license_url
    ])
    |> validate_required(@required_fields)
  end
end
