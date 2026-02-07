defmodule OakCompendium.Taxonomy do
  @moduledoc """
  The Taxonomy context.

  Provides functions for querying the taxonomic hierarchy
  (subgenus, section, subsection, complex).
  """

  import Ecto.Query

  alias OakCompendium.Repo
  alias OakCompendium.Species.Species, as: SpeciesSchema
  alias OakCompendium.Taxonomy.Taxon

  @valid_levels ~w(subgenus section subsection complex)

  @child_level_map %{
    "subgenus" => "section",
    "section" => "subsection",
    "subsection" => "complex"
  }

  @taxonomy_fields [:subgenus, :section, :subsection, :complex]

  @species_count_sql "(SELECT COUNT(*) FROM species sp WHERE " <>
                       "(? = 'subgenus' AND sp.subgenus = ?) OR " <>
                       "(? = 'section' AND sp.section = ?) OR " <>
                       "(? = 'subsection' AND sp.subsection = ?) OR " <>
                       "(? = 'complex' AND sp.complex = ?))"

  # -- List --

  @doc """
  Returns all taxa, optionally filtered by level and/or parent.

  ## Options
    * `"level"` - filter by taxonomic level
    * `"parent"` - filter by parent taxon name
  """
  @spec list_taxa(map()) :: [Taxon.t()]
  def list_taxa(params \\ %{}) do
    Taxon
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent"])
    |> order_by([t], asc: t.level, asc: t.name)
    |> Repo.all()
  end

  @doc """
  Returns taxa at a given level, ordered by name.
  """
  @spec list_taxa_by_level(String.t()) :: [Taxon.t()]
  def list_taxa_by_level(level) do
    list_taxa(%{"level" => level})
  end

  @doc """
  Returns taxa with species counts, optionally filtered by level and/or parent.

  Each returned taxon has its virtual `species_count` field populated
  with the count of species matching that taxon's level and name.

  ## Options
    * `"level"` - filter by taxonomic level
    * `"parent"` - filter by parent taxon name
  """
  @spec list_taxa_with_counts(map()) :: [Taxon.t()]
  def list_taxa_with_counts(params \\ %{}) do
    from(t in Taxon,
      select_merge: %{
        species_count:
          fragment(
            @species_count_sql,
            t.level,
            t.name,
            t.level,
            t.name,
            t.level,
            t.name,
            t.level,
            t.name
          )
      }
    )
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent"])
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  # -- Get --

  @doc """
  Returns a taxon by level and name, or nil if not found.
  """
  @spec get_taxon(String.t(), String.t()) :: Taxon.t() | nil
  def get_taxon(level, name) do
    if level in @valid_levels do
      Repo.get_by(Taxon, level: level, name: name)
    end
  end

  @doc """
  Returns a taxon by ID, or nil if not found.
  """
  @spec get_taxon_by_id(integer()) :: Taxon.t() | nil
  def get_taxon_by_id(id) do
    Repo.get(Taxon, id)
  end

  # -- Children --

  @doc """
  Returns child taxa of a given taxon, with species counts populated.

  The child level is determined by the taxon's level:
  subgenus → section, section → subsection, subsection → complex.
  Complex taxa have no children (returns empty list).
  """
  @spec get_children(Taxon.t()) :: [Taxon.t()]
  def get_children(%Taxon{} = taxon) do
    case Map.get(@child_level_map, taxon.level) do
      nil -> []
      child_level -> list_taxa_with_counts(%{"level" => child_level, "parent" => taxon.name})
    end
  end

  # -- Species in taxon --

  @doc """
  Returns species at exactly the given taxonomy path.

  The path is a list of taxon names encoding the hierarchy,
  e.g. `["Quercus", "Quercus"]` for section Quercus within
  subgenus Quercus.

  Uses "gap filters" to return only species at that exact level:
  species matching the path must have the next taxonomy field
  (below the path depth) be NULL or empty.
  """
  @spec get_species_in_taxon([String.t()]) :: [SpeciesSchema.t()]
  def get_species_in_taxon(path) when is_list(path) do
    depth = length(path)

    query = from(s in SpeciesSchema, order_by: [asc: s.scientific_name])

    # Apply positive filters for each path segment
    query =
      path
      |> Enum.zip(@taxonomy_fields)
      |> Enum.reduce(query, fn {value, field}, q ->
        where(q, [s], field(s, ^field) == ^value)
      end)

    # Apply gap filter: next taxonomy field must be NULL or empty
    case Enum.at(@taxonomy_fields, depth) do
      nil ->
        Repo.all(query)

      gap_field ->
        query
        |> where([s], is_nil(field(s, ^gap_field)) or field(s, ^gap_field) == "")
        |> Repo.all()
    end
  end

  # -- Counts --

  @doc """
  Returns the total count of taxa.
  """
  @spec count() :: integer()
  def count do
    Repo.aggregate(Taxon, :count)
  end

  @doc """
  Returns the list of valid taxonomic levels.
  """
  @spec valid_levels() :: [String.t()]
  def valid_levels, do: @valid_levels

  # -- Serialization --

  @doc """
  Converts a taxon struct to an API response map.
  """
  @spec to_map(Taxon.t()) :: map()
  def to_map(taxon) do
    links = parse_json(taxon.links)

    %{
      id: taxon.id,
      name: taxon.name,
      level: taxon.level,
      parent: taxon.parent,
      author: taxon.author,
      content: taxon.content,
      content_updated_at: taxon.content_updated_at,
      links: links
    }
  end

  # -- Private --

  defp maybe_filter_level(query, nil), do: query
  defp maybe_filter_level(query, ""), do: query

  defp maybe_filter_level(query, level) do
    if level in @valid_levels do
      where(query, [t], t.level == ^level)
    else
      query
    end
  end

  defp maybe_filter_parent(query, nil), do: query
  defp maybe_filter_parent(query, ""), do: query
  defp maybe_filter_parent(query, parent), do: where(query, [t], t.parent == ^parent)

  defp parse_json(nil), do: nil
  defp parse_json(""), do: nil

  defp parse_json(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, data} -> data
      _ -> nil
    end
  end
end
