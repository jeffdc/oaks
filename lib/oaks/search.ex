defmodule Oaks.Search do
  @moduledoc """
  Unified search across species, taxa, and sources.

  Searches multiple entity types in a single call and returns
  results grouped by type with counts. Matches V1 API behavior:
  species are searched by scientific_name, author, synonyms, and
  common names (local_names via species_sources); taxa by name;
  sources by name and author.
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species
  alias Oaks.Taxonomy.Taxon

  @default_limit 50
  @max_limit 500

  @level_hierarchy %{
    "complex" => "subsection",
    "subsection" => "section",
    "section" => "subgenus",
    "subgenus" => nil
  }

  @doc """
  Searches across species, taxa, and sources. Returns results grouped by type
  with counts.

  Species are searched by scientific_name, author, synonyms, and common names
  (local_names from species_sources). Taxa are searched by name. Sources are
  searched by name and author.

  All searches are case-insensitive using SQLite-compatible `lower(?) LIKE ?`.

  ## Examples

      iex> Search.search("alba")
      %{
        species: [%{scientific_name: "alba", ...}],
        taxa: [],
        sources: [],
        counts: %{species: 1, taxa: 0, sources: 0, total: 1}
      }
  """
  @spec search(String.t(), integer()) :: map()
  def search(query, limit \\ @default_limit) do
    limit = min(max(limit, 1), @max_limit)
    term = "%#{sanitize_like(String.downcase(query))}%"

    species = search_species(term, limit)
    taxa = search_taxa(term, limit)
    sources = search_sources(term, limit)

    %{
      species: species,
      taxa: taxa,
      sources: sources,
      counts: %{
        species: length(species),
        taxa: length(taxa),
        sources: length(sources),
        total: length(species) + length(taxa) + length(sources)
      }
    }
  end

  defp search_species(term, limit) do
    # Use a subquery to find matching species IDs (avoiding DISTINCT multi-column,
    # which SQLite doesn't support). The left join on species_sources allows
    # matching by common name (local_names).
    matching_ids =
      from(s in Species,
        left_join: ss in SpeciesSource,
        on: ss.species_id == s.id,
        where:
          fragment("lower(?) LIKE ?", s.scientific_name, ^term) or
            fragment("lower(?) LIKE ?", s.author, ^term) or
            fragment("lower(?) LIKE ?", s.synonyms, ^term) or
            fragment("lower(?) LIKE ?", ss.local_names, ^term),
        select: s.id
      )

    from(s in Species,
      where: s.id in subquery(matching_ids),
      order_by: [asc: s.scientific_name],
      limit: ^limit,
      select: %{
        id: s.id,
        scientific_name: s.scientific_name,
        author: s.author,
        is_hybrid: s.is_hybrid,
        subgenus: s.subgenus,
        section: s.section
      }
    )
    |> Repo.all()
  end

  defp search_taxa(term, limit) do
    taxa =
      from(t in Taxon,
        where: fragment("lower(?) LIKE ?", t.name, ^term),
        order_by: [asc: t.level, asc: t.name],
        limit: ^limit,
        select: %{
          id: t.id,
          name: t.name,
          level: t.level,
          parent: t.parent,
          author: t.author
        }
      )
      |> Repo.all()

    taxa
    |> add_species_counts()
    |> add_ancestry_paths()
  end

  defp search_sources(term, limit) do
    from(s in Source,
      where:
        fragment("lower(?) LIKE ?", s.name, ^term) or
          fragment("lower(?) LIKE ?", s.author, ^term),
      order_by: [asc: s.name],
      limit: ^limit,
      select: %{
        id: s.id,
        name: s.name,
        source_type: s.source_type,
        author: s.author,
        year: s.year,
        url: s.url
      }
    )
    |> Repo.all()
  end

  defp add_species_counts(taxa) do
    Enum.map(taxa, fn taxon ->
      count = species_count_for_taxon(taxon.level, taxon.name)
      Map.put(taxon, :species_count, count)
    end)
  end

  defp species_count_for_taxon(level, name) do
    field_atom = level_to_species_field(level)

    if field_atom do
      from(s in Species, where: field(s, ^field_atom) == ^name)
      |> Repo.aggregate(:count)
    else
      0
    end
  end

  defp level_to_species_field("subgenus"), do: :subgenus
  defp level_to_species_field("section"), do: :section
  defp level_to_species_field("subsection"), do: :subsection
  defp level_to_species_field("complex"), do: :complex
  defp level_to_species_field(_), do: nil

  defp add_ancestry_paths(taxa) do
    # Build lookup map of all taxa for walking parent chains
    all_taxa =
      from(t in Taxon, select: %{name: t.name, level: t.level, parent: t.parent})
      |> Repo.all()

    taxa_map =
      Map.new(all_taxa, fn t -> {{t.name, t.level}, t.parent} end)

    Enum.map(taxa, fn taxon ->
      path = compute_path(taxon.name, taxon.level, taxa_map, MapSet.new())
      Map.put(taxon, :path, path)
    end)
  end

  defp compute_path(name, level, taxa_map, visited) do
    key = {name, level}

    if MapSet.member?(visited, key) do
      [name]
    else
      visited = MapSet.put(visited, key)
      walk_parent(name, level, taxa_map, visited)
    end
  end

  defp walk_parent(name, level, taxa_map, visited) do
    parent_name = Map.get(taxa_map, {name, level})
    parent_level = Map.get(@level_hierarchy, level)

    if parent_name && parent_level do
      compute_path(parent_name, parent_level, taxa_map, visited) ++ [name]
    else
      [name]
    end
  end

  defp sanitize_like(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
