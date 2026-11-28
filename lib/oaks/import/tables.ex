defmodule Oaks.Import.Tables do
  @moduledoc """
  The tables a bulk import (`Oaks.Import`) can write, in the order it
  processes them.

  Each entry names the body key (the table's name), the Ecto schema whose
  `changeset/2` every record goes through, the foreign keys that may point at
  other records in the body (`refs`: field => target table), the fields an
  update may not change (`immutable_on_update`: the app cascades renames, the
  import doesn't), and an optional `prepare` hook that adjusts a valid
  changeset before it is written.

  The import is the one writer that bypasses the contexts, on purpose: it
  needs every write in one transaction that keeps going after an error, so
  it calls the schemas' changesets directly. A hook copies whatever a context
  adds on top of its changeset (see the taxa entry).

  Records are processed table by table in this order, then in array order,
  so a record can refer only to records before it. A new model adds its
  tables here.
  """

  alias Oaks.Sources.Source
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Species.Species
  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  @type action :: :create | :update

  @type t :: %{
          name: String.t(),
          schema: module(),
          changeset: (struct(), map() -> Ecto.Changeset.t()),
          refs: %{atom() => String.t()},
          immutable_on_update: [atom()],
          prepare: (Ecto.Changeset.t(), action() -> Ecto.Changeset.t()) | nil
        }

  @doc "Every importable table, in processing order."
  @spec all() :: [t()]
  def all do
    [
      %{
        name: "sources",
        schema: Source,
        changeset: &Source.changeset/2,
        refs: %{},
        immutable_on_update: [],
        prepare: nil
      },
      %{
        name: "taxa",
        schema: Taxon,
        changeset: &Taxon.changeset/2,
        refs: %{parent_id: "taxa"},
        immutable_on_update: [:name, :level],
        prepare: &prepare_taxon/2
      },
      %{
        name: "species",
        schema: Species,
        changeset: &Species.changeset/2,
        refs: %{taxon_id: "taxa", parent1_id: "species", parent2_id: "species"},
        immutable_on_update: [:scientific_name],
        prepare: nil
      },
      %{
        name: "species_sources",
        schema: SpeciesSource,
        changeset: &SpeciesSource.changeset/2,
        refs: %{species_id: "species", source_id: "sources"},
        immutable_on_update: [],
        prepare: nil
      }
    ]
  end

  @doc "The names of every importable table, in processing order."
  @spec names() :: [String.t()]
  def names, do: Enum.map(all(), & &1.name)

  @doc """
  The fields a record of `table` may set: the schema's fields except `id`.
  """
  @spec fields(t()) :: [atom()]
  def fields(table), do: table.schema.__schema__(:query_fields) -- [:id]

  # What Oaks.Taxonomy adds on top of the changeset: the rank rule on create
  # and update, and an update that changes the content stamps
  # content_updated_at with today's date.
  defp prepare_taxon(changeset, action) do
    changeset
    |> Taxonomy.validate_parent_rank()
    |> stamp_taxon_content(action)
  end

  defp stamp_taxon_content(changeset, :update) do
    if Ecto.Changeset.changed?(changeset, :content) do
      Ecto.Changeset.put_change(changeset, :content_updated_at, Date.to_iso8601(Date.utc_today()))
    else
      changeset
    end
  end

  defp stamp_taxon_content(changeset, :create), do: changeset
end
