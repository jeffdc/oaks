defmodule Oaks.Sources.Source do
  @moduledoc """
  Ecto schema for the sources table.

  Represents a data source (website, book, personal observation, etc.)
  that provides information about oak species.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Oaks.ChangesetHelpers

  alias Oaks.Sources.SpeciesSource

  @required_fields [:source_type, :name]

  @type t :: %__MODULE__{}

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
    |> trim_strings()
    |> validate_required(@required_fields)
    |> validate_url(:url)
    |> validate_url(:license_url)
  end
end
