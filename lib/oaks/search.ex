defmodule Oaks.Search do
  @moduledoc """
  Unified search across species, taxa, and sources.

  Searches multiple entity types in a single call and returns
  results grouped by type with counts. Matches V1 API behavior:
  species are searched by scientific_name, author, synonyms, and
  common names (local_names via species_sources); taxa by name;
  sources by name and author.

  Species and taxa carry their place in the taxonomy, read from the keys:
  a species' subgenus and section, a taxon's species count and the path of
  names from the subgenus down.
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species
  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  @default_limit 50
  @max_limit 500

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

  @doc """
  Says which synonym each species in a search's results was found through.

  Takes the species from `search/2` and the same query. A species whose own
  name contains the query is left out; for any other, the first of its
  synonyms that contains the query (case-insensitive, as `search/2` matches)
  is returned as `%{name: name, author: author}`. A species found only by its
  author or a common name is left out too, as is a stored synonym string
  that joins several names with "=". The author is nil for a synonym stored
  as a string, which keeps its authority in the name.

  ## Examples

      iex> Search.synonym_matches(Search.search("candida").species, "candida")
      %{12 => %{name: "candida Steud.", author: nil}}
  """
  @spec synonym_matches([map()], String.t()) :: %{
          integer() => %{name: String.t(), author: String.t() | nil}
        }
  def synonym_matches([], _query), do: %{}

  def synonym_matches(species, query) do
    needle = String.downcase(query)
    ids = Enum.map(species, & &1.id)

    from(s in Species, where: s.id in ^ids, select: {s.id, s.scientific_name, s.synonyms})
    |> Repo.all()
    |> Enum.reject(fn {_id, name, _synonyms} -> contains?(name, needle) end)
    |> Enum.flat_map(fn {id, _name, synonyms} ->
      synonyms
      |> Oaks.Species.parse_json_array()
      |> Enum.flat_map(&synonym_entry/1)
      |> Enum.find(&contains?(synonym_text(&1), needle))
      |> case do
        nil -> []
        synonym -> [{id, synonym}]
      end
    end)
    |> Map.new()
  end

  defp contains?(text, needle), do: String.contains?(String.downcase(text), needle)

  # A synonym is stored as a string, or as %{"name" => ..., "author" => ...}.
  # A string holding several names joined by "=" (a few hybrids' records)
  # isn't one name to show, so it is passed over.
  defp synonym_entry(name) when is_binary(name) do
    if String.contains?(name, "="), do: [], else: [%{name: name, author: nil}]
  end

  defp synonym_entry(%{"name" => name} = entry) when is_binary(name) do
    author = entry["author"]
    [%{name: name, author: if(is_binary(author) and author != "", do: author)}]
  end

  defp synonym_entry(_other), do: []

  defp synonym_text(%{name: name, author: nil}), do: name
  defp synonym_text(%{name: name, author: author}), do: name <> " " <> author

  defp search_species(term, limit) do
    # Use a subquery to find matching species IDs (avoiding DISTINCT multi-column,
    # which SQLite doesn't support). The left join on species_sources allows
    # matching by common name (local_names).
    matching_ids =
      from(s in Species,
        left_join: ss in SpeciesSource,
        on: ss.species_id == s.id,
        where:
          fragment("lower(?) LIKE ? ESCAPE '\\'", s.scientific_name, ^term) or
            fragment("lower(?) LIKE ? ESCAPE '\\'", s.author, ^term) or
            fragment("lower(?) LIKE ? ESCAPE '\\'", s.synonyms, ^term) or
            fragment("lower(?) LIKE ? ESCAPE '\\'", ss.local_names, ^term),
        select: s.id
      )

    species =
      from(s in Species,
        where: s.id in subquery(matching_ids),
        order_by: [asc: s.scientific_name],
        limit: ^limit,
        select: %{
          id: s.id,
          scientific_name: s.scientific_name,
          author: s.author,
          is_hybrid: s.is_hybrid,
          taxon_id: s.taxon_id
        }
      )
      |> Repo.all()

    index = ancestry_index()
    Enum.map(species, &put_ancestor_names(&1, index))
  end

  defp put_ancestor_names(species, index) do
    ranks = ranks_for(species.taxon_id, index)

    Map.merge(species, %{
      subgenus: name_at(ranks, "subgenus"),
      section: name_at(ranks, "section")
    })
  end

  defp search_taxa(term, limit) do
    taxa =
      from(t in Taxon,
        where: fragment("lower(?) LIKE ? ESCAPE '\\'", t.name, ^term),
        order_by: [asc: t.level, asc: t.name],
        limit: ^limit,
        select: %{
          id: t.id,
          name: t.name,
          level: t.level,
          parent_id: t.parent_id,
          author: t.author
        }
      )
      |> Repo.all()

    counts =
      Taxonomy.list_taxa_with_counts()
      |> Map.new(&{&1.id, &1.species_count})

    index = ancestry_index()

    Enum.map(taxa, fn taxon ->
      taxon
      |> Map.put(:species_count, Map.get(counts, taxon.id, 0))
      |> Map.put(:path, Enum.map(ranks_for(taxon.id, index), & &1.name))
    end)
  end

  defp search_sources(term, limit) do
    from(s in Source,
      where:
        fragment("lower(?) LIKE ? ESCAPE '\\'", s.name, ^term) or
          fragment("lower(?) LIKE ? ESCAPE '\\'", s.author, ^term),
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

  # Each taxon's ancestry (the genus down to itself), from one taxonomy
  # call rather than a walk of its own.
  defp ancestry_index do
    Taxonomy.list_taxa_with_ancestors()
    |> Map.new(fn %{taxon: taxon, ancestors: ancestors} -> {taxon.id, ancestors ++ [taxon]} end)
  end

  # The ranks from the subgenus down to the taxon; the genus is left out
  # (its page is the taxonomy index).
  defp ranks_for(nil, _index), do: []
  defp ranks_for(id, index), do: index |> Map.get(id, []) |> Enum.reject(&(&1.level == "genus"))

  defp name_at(ranks, level) do
    Enum.find_value(ranks, fn taxon -> taxon.level == level && taxon.name end)
  end

  defp sanitize_like(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
