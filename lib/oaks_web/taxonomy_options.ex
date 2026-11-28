defmodule OaksWeb.TaxonomyOptions do
  @moduledoc """
  Select options for taxa, labelled with the rank and the ancestry, so a
  repeated name ("Quercus" is a subgenus and a section) is unambiguous.

  The species form uses every taxon in tree order; the taxon form uses only
  the taxa ranked above the chosen level.
  """

  alias Oaks.Taxonomy
  alias OaksWeb.SpeciesName

  @doc """
  Every taxon in tree order, as `{label, id}`.
  """
  @spec all() :: [{String.t(), integer()}]
  def all do
    Taxonomy.list_taxa_with_ancestors()
    |> Enum.map(&option/1)
  end

  @doc """
  The taxa ranked above `level`, outermost first, as `{label, id}`.
  """
  @spec above(String.t() | nil) :: [{String.t(), integer()}]
  def above(level) do
    case Taxonomy.level_rank(level) do
      nil ->
        []

      rank ->
        Taxonomy.list_taxa_with_ancestors()
        |> Enum.filter(fn %{taxon: taxon} -> Taxonomy.level_rank(taxon.level) < rank end)
        |> Enum.map(&option/1)
    end
  end

  defp option(%{taxon: taxon, ancestors: ancestors}) do
    {Enum.map_join(ancestors ++ [taxon], " / ", &label/1), taxon.id}
  end

  defp label(taxon) do
    "#{String.capitalize(taxon.level)} #{SpeciesName.taxon_label(taxon.level, taxon.name)}"
  end
end
