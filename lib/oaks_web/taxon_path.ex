defmodule OaksWeb.TaxonPath do
  @moduledoc """
  The path the taxonomy band (`OaksWeb.DesignComponents.taxonomy_band/1`)
  shows: the genus, then each taxon a page sits under, each with the page
  it links to. Every taxon page builds its band from here, so the band
  reads the same on taxonomy, species, hybrid, variety and comparison
  pages.

  A step is a map with `level` ("genus", "subgenus", "section",
  "subsection", "complex" or "species"), `name`, `hybrid` (a named
  hybrid's species) and, for the steps before the current one, `path`.
  """

  use OaksWeb, :verified_routes

  alias Oaks.Taxonomy

  @type step :: %{
          required(:level) => String.t(),
          required(:name) => String.t(),
          required(:hybrid) => boolean(),
          optional(:path) => String.t()
        }

  @doc """
  Returns the band's linked steps for a placement, outermost first: the
  genus row, then each entry of the placement (as from
  `Oaks.Species.placement/1`, or a taxon's ancestors) with its path. Taxa
  link to their taxonomy page, a variety's species to its species page.

      iex> OaksWeb.TaxonPath.ranks([%{level: "subgenus", name: "Cerris", hybrid: false}])
      [
        %{level: "genus", name: "Quercus", hybrid: false, path: "/taxonomy"},
        %{level: "subgenus", name: "Cerris", hybrid: false, path: "/taxonomy/Cerris"}
      ]
  """
  @spec ranks([%{level: String.t(), name: String.t(), hybrid: boolean()}]) :: [step()]
  def ranks(placement) do
    {steps, _segments} =
      Enum.map_reduce(placement, [], fn
        %{level: "species"} = step, segments ->
          {Map.put(step, :path, ~p"/species/#{step.name}"), segments}

        step, segments ->
          segments = segments ++ [step.name]
          {Map.put(step, :path, taxonomy_path(segments)), segments}
      end)

    [genus_step() | steps]
  end

  defp genus_step do
    genus = Taxonomy.get_genus()
    %{level: "genus", name: genus.name, hybrid: false, path: ~p"/taxonomy"}
  end

  @doc """
  Returns the band's current step for a species record.
  """
  @spec current(%{scientific_name: String.t(), is_hybrid: boolean() | nil}) :: step()
  def current(species) do
    %{level: "species", name: species.scientific_name, hybrid: species.is_hybrid == true}
  end

  @doc """
  Returns the taxonomy page path for a list of taxon names, outermost
  first.

      iex> OaksWeb.TaxonPath.taxonomy_path(["Quercus", "Lobatae"])
      "/taxonomy/Quercus/Lobatae"
  """
  @spec taxonomy_path([String.t()]) :: String.t()
  def taxonomy_path([]), do: ~p"/taxonomy"

  def taxonomy_path(segments) do
    "/taxonomy/" <>
      Enum.map_join(segments, "/", &URI.encode(&1, fn c -> URI.char_unreserved?(c) end))
  end
end
