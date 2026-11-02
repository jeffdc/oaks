defmodule Oaks.Taxonomy do
  @moduledoc """
  The Taxonomy context.

  Provides functions for querying the taxonomic hierarchy
  (subgenus, section, subsection, complex).
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Species.Species, as: SpeciesSchema
  alias Oaks.Taxonomy.Taxon

  @valid_levels ~w(subgenus section subsection complex)

  @level_fields %{
    "subgenus" => :subgenus,
    "section" => :section,
    "subsection" => :subsection,
    "complex" => :complex
  }

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
    Taxon
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent"])
    |> order_by([t], asc: t.name)
    |> with_species_counts()
  end

  defp with_species_counts(query) do
    from(t in query,
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

  Subgenera contain sections, sections contain subsections and complexes
  placed directly under them, subsections contain complexes, and complexes
  have no children.
  """
  @spec get_children(Taxon.t()) :: [Taxon.t()]
  def get_children(%Taxon{} = taxon) do
    taxon
    |> child_taxa_query()
    |> order_by([t], desc: t.level == "subsection", asc: t.name)
    |> with_species_counts()
  end

  @doc """
  Resolves a browse path of taxon names (e.g. `["Quercus", "Quercus", "robur"]`)
  into the taxa it names, walking from subgenus down through each taxon's
  children. Returns `:error` if any segment isn't a child of the one before.
  """
  @spec resolve_path([String.t()]) :: {:ok, [Taxon.t()]} | :error
  def resolve_path([]), do: {:ok, []}

  def resolve_path([subgenus | rest]) do
    case get_taxon("subgenus", subgenus) do
      nil -> :error
      taxon -> resolve_children(rest, [taxon])
    end
  end

  defp resolve_children([], resolved), do: {:ok, Enum.reverse(resolved)}

  defp resolve_children([name | rest], [parent | _] = resolved) do
    case parent |> child_taxa_query() |> where([t], t.name == ^name) |> Repo.all() do
      [taxon | _] -> resolve_children(rest, [taxon | resolved])
      [] -> :error
    end
  end

  # -- Species in taxon --

  @doc """
  Returns the species that sit directly in the taxon at the given path,
  i.e. not in one of its child taxa.

  The path is a list of taxon names encoding the hierarchy, e.g.
  `["Quercus", "Quercus"]` for section Quercus within subgenus Quercus
  (see `resolve_path/1`). An empty path returns species with no subgenus.
  Unknown paths return an empty list.
  """
  @spec get_species_in_taxon([String.t()]) :: [SpeciesSchema.t()]
  def get_species_in_taxon([]) do
    from(s in SpeciesSchema,
      where: is_nil(s.subgenus) or s.subgenus == "",
      order_by: [asc: s.scientific_name]
    )
    |> Repo.all()
  end

  def get_species_in_taxon(path) when is_list(path) do
    case resolve_path(path) do
      {:ok, taxa} -> species_directly_in(taxa)
      :error -> []
    end
  end

  defp species_directly_in(taxa) do
    base = from(s in SpeciesSchema, order_by: [asc: s.scientific_name])
    query = Enum.reduce(taxa, base, &filter_by_taxon/2)

    taxa
    |> List.last()
    |> exclude_child_species(query)
    |> Repo.all()
  end

  defp filter_by_taxon(taxon, query) do
    field = Map.fetch!(@level_fields, taxon.level)
    where(query, [s], field(s, ^field) == ^taxon.name)
  end

  # Species assigned to one of the taxon's child taxa belong to that child.
  defp exclude_child_species(%Taxon{level: "subgenus"}, query) do
    where(query, [s], is_nil(s.section) or s.section == "")
  end

  defp exclude_child_species(%Taxon{level: "section"} = taxon, query) do
    direct_complexes =
      taxon
      |> child_taxa_query()
      |> where([t], t.level == "complex")
      |> select([t], t.name)
      |> Repo.all()

    where(
      query,
      [s],
      (is_nil(s.subsection) or s.subsection == "") and
        (is_nil(s.complex) or s.complex == "" or s.complex not in ^direct_complexes)
    )
  end

  defp exclude_child_species(%Taxon{level: "subsection"}, query) do
    where(query, [s], is_nil(s.complex) or s.complex == "")
  end

  defp exclude_child_species(%Taxon{}, query), do: query

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

  # -- Changesets --

  @doc """
  Returns a changeset for tracking taxon changes.
  """
  @spec change_taxon(Taxon.t(), map()) :: Ecto.Changeset.t()
  def change_taxon(%Taxon{} = taxon, attrs \\ %{}) do
    Taxon.changeset(taxon, attrs)
  end

  # -- Mutations --

  @doc """
  Creates a new taxon with the given attributes.
  """
  @spec create_taxon(map()) :: {:ok, Taxon.t()} | {:error, Ecto.Changeset.t()}
  def create_taxon(attrs) do
    %Taxon{}
    |> Taxon.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a taxon with the given attributes.

  The level can't change after creation. Species and child taxa refer to a
  taxon by name, so a rename also updates those references in the same
  transaction. Changing the content stamps `content_updated_at` with today's date.
  """
  @spec update_taxon(Taxon.t(), map()) :: {:ok, Taxon.t()} | {:error, Ecto.Changeset.t()}
  def update_taxon(%Taxon{} = taxon, attrs) do
    changeset =
      taxon
      |> Taxon.changeset(Map.drop(attrs, ["level", :level]))
      |> stamp_content_updated()

    case Ecto.Changeset.fetch_change(changeset, :name) do
      {:ok, new_name} -> rename_taxon(taxon, changeset, new_name)
      :error -> Repo.update(changeset)
    end
  end

  defp rename_taxon(taxon, changeset, new_name) do
    field = Map.fetch!(@level_fields, taxon.level)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:taxon, changeset)
    |> Ecto.Multi.update_all(
      :species,
      from(s in SpeciesSchema, where: field(s, ^field) == ^taxon.name),
      set: [{field, new_name}]
    )
    |> Ecto.Multi.update_all(:children, child_taxa_query(taxon), set: [parent: new_name])
    |> Repo.transaction()
    |> case do
      {:ok, %{taxon: updated}} -> {:ok, updated}
      {:error, :taxon, changeset, _} -> {:error, changeset}
    end
  end

  defp stamp_content_updated(changeset) do
    if Ecto.Changeset.changed?(changeset, :content) do
      Ecto.Changeset.put_change(changeset, :content_updated_at, Date.to_iso8601(Date.utc_today()))
    else
      changeset
    end
  end

  @doc """
  Returns how many species and direct child taxa refer to the taxon.
  """
  @spec taxon_usage(Taxon.t()) :: %{species: non_neg_integer(), children: non_neg_integer()}
  def taxon_usage(%Taxon{} = taxon) do
    field = Map.fetch!(@level_fields, taxon.level)

    %{
      species:
        Repo.aggregate(from(s in SpeciesSchema, where: field(s, ^field) == ^taxon.name), :count),
      children: Repo.aggregate(child_taxa_query(taxon), :count)
    }
  end

  @doc """
  Deletes a taxon, refusing while species or child taxa still refer to it.
  """
  @spec delete_taxon(Taxon.t()) ::
          {:ok, Taxon.t()} | {:error, {:in_use, map()}} | {:error, Ecto.Changeset.t()}
  def delete_taxon(%Taxon{} = taxon) do
    Repo.transaction(fn ->
      case taxon_usage(taxon) do
        %{species: 0, children: 0} -> delete_or_rollback(taxon)
        usage -> Repo.rollback({:in_use, usage})
      end
    end)
  end

  defp delete_or_rollback(taxon) do
    case Repo.delete(taxon) do
      {:ok, deleted} -> deleted
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  # Direct children of a taxon. Children store only the parent's name, so the
  # parent's level is implied by the child's level. A complex can sit directly
  # under a section; when a subsection shares the section's name, complexes
  # with that parent name belong to the subsection.
  defp child_taxa_query(%Taxon{level: "subgenus", name: name}) do
    from(t in Taxon, where: t.level == "section" and t.parent == ^name)
  end

  defp child_taxa_query(%Taxon{level: "section", name: name}) do
    levels =
      if Repo.exists?(from(t in Taxon, where: t.level == "subsection" and t.name == ^name)),
        do: ["subsection"],
        else: ["subsection", "complex"]

    from(t in Taxon, where: t.level in ^levels and t.parent == ^name)
  end

  defp child_taxa_query(%Taxon{level: "subsection", name: name}) do
    from(t in Taxon, where: t.level == "complex" and t.parent == ^name)
  end

  defp child_taxa_query(%Taxon{}), do: from(t in Taxon, where: false)

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
