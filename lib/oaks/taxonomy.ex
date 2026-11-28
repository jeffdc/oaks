defmodule Oaks.Taxonomy do
  @moduledoc """
  The Taxonomy context.

  Provides functions for querying and managing the taxonomic hierarchy
  (genus, subgenus, section, subsection, complex). A taxon's `parent_id`
  points at the rank above it; only the genus (*Quercus*) has no parent.
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Species.Species, as: SpeciesSchema
  alias Oaks.Taxonomy.Taxon

  @levels ~w(genus subgenus section subsection complex)
  @valid_levels @levels
  @genus_level "genus"

  # -- List --

  @doc """
  Returns all taxa, optionally filtered by level and/or parent.

  ## Options
    * `"level"` - filter by taxonomic level
    * `"parent_id"` - filter by the parent taxon's id
  """
  @spec list_taxa(map()) :: [Taxon.t()]
  def list_taxa(params \\ %{}) do
    Taxon
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent_id"])
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
  Returns every taxon in tree order (the genus, then each child's subtree,
  siblings by name), each with its ancestors, outermost first.
  """
  @spec list_taxa_with_ancestors() :: [%{taxon: Taxon.t(), ancestors: [Taxon.t()]}]
  def list_taxa_with_ancestors do
    children = Taxon |> order_by(asc: :name) |> Repo.all() |> Enum.group_by(& &1.parent_id)
    roots = Map.get(children, nil, [])

    Enum.flat_map(roots, &[%{taxon: &1, ancestors: []} | subtree(children, &1, [&1])])
  end

  defp subtree(children, parent, ancestors) do
    children
    |> Map.get(parent.id, [])
    |> Enum.flat_map(fn child ->
      [%{taxon: child, ancestors: ancestors} | subtree(children, child, ancestors ++ [child])]
    end)
  end

  @doc """
  Returns taxa with species counts, optionally filtered by level and/or
  parent.

  Each returned taxon's virtual `species_count` is the number of species in
  its subtree: those placed at the taxon or at any taxon below it.

  ## Options
    * `"level"` - filter by taxonomic level
    * `"parent_id"` - filter by the parent taxon's id
  """
  @spec list_taxa_with_counts(map()) :: [Taxon.t()]
  def list_taxa_with_counts(params \\ %{}) do
    Taxon
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent_id"])
    |> order_by([t], asc: t.name)
    |> Repo.all()
    |> with_species_counts()
  end

  defp with_species_counts(taxa) do
    counts = subtree_species_counts()
    Enum.map(taxa, &%{&1 | species_count: Map.get(counts, &1.id, 0)})
  end

  # The number of species in each taxon's subtree, from one query for the
  # species at each taxon and one pass over the tree.
  defp subtree_species_counts do
    all = Repo.all(Taxon)
    children = Enum.group_by(all, & &1.parent_id)

    direct =
      from(s in SpeciesSchema,
        where: not is_nil(s.taxon_id),
        group_by: s.taxon_id,
        select: {s.taxon_id, count(s.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(all, fn taxon ->
      {taxon.id, count_subtree(children, direct, taxon.id)}
    end)
  end

  defp count_subtree(children, direct, id) do
    Map.get(direct, id, 0) +
      Enum.sum(Enum.map(Map.get(children, id, []), &count_subtree(children, direct, &1.id)))
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

  @doc """
  Returns the genus row (*Quercus*), the root of the taxonomy.
  """
  @spec get_genus() :: Taxon.t() | nil
  def get_genus do
    Repo.get_by(Taxon, level: @genus_level)
  end

  @doc """
  Returns the taxa from the genus down to `taxon`, inclusive.
  """
  @spec ancestors(Taxon.t()) :: [Taxon.t()]
  def ancestors(%Taxon{} = taxon) do
    case taxon.parent_id do
      nil -> [taxon]
      parent_id -> ancestors(get_taxon_by_id(parent_id)) ++ [taxon]
    end
  end

  @doc """
  Returns the taxa from the genus down to the taxon with `id`, inclusive;
  an empty list for nil or an unknown id.
  """
  @spec ancestry(integer() | nil) :: [Taxon.t()]
  def ancestry(nil), do: []

  def ancestry(id) do
    case get_taxon_by_id(id) do
      nil -> []
      taxon -> ancestors(taxon)
    end
  end

  @doc """
  Returns the ids of `taxon` and every taxon below it.
  """
  @spec subtree_ids(Taxon.t()) :: [integer()]
  def subtree_ids(%Taxon{} = taxon) do
    [taxon.id | Enum.flat_map(children(taxon), &subtree_ids/1)]
  end

  # -- Levels --

  @doc """
  Returns every taxonomic level, outermost first.
  """
  @spec levels() :: [String.t()]
  def levels, do: @levels

  @doc """
  Returns the list of valid taxonomic levels.
  """
  @spec valid_levels() :: [String.t()]
  def valid_levels, do: @valid_levels

  @doc """
  Returns a level's depth in the hierarchy (the genus is 0), or nil for an
  unknown level.
  """
  @spec level_rank(String.t()) :: non_neg_integer() | nil
  def level_rank(level), do: Enum.find_index(@levels, &(&1 == level))

  @doc """
  Returns the levels ranked above `level`, outermost first.
  """
  @spec levels_above(String.t()) :: [String.t()]
  def levels_above(level) do
    case level_rank(level) do
      nil -> []
      rank -> Enum.take(@levels, rank)
    end
  end

  # -- Children --

  @doc """
  Returns child taxa of a given taxon, with species counts populated.

  A section's children are its subsections and any complexes placed directly
  under it; the subsections come first.
  """
  @spec get_children(Taxon.t()) :: [Taxon.t()]
  def get_children(%Taxon{} = taxon) do
    taxon
    |> children()
    |> Enum.sort_by(&{&1.level != "subsection", &1.name})
    |> with_species_counts()
  end

  defp children(%Taxon{id: id}) do
    Repo.all(from(t in Taxon, where: t.parent_id == ^id))
  end

  @doc """
  Resolves a browse path of taxon names (e.g. `["Quercus", "Quercus", "robur"]`)
  into the taxa it names, walking from the genus down through each taxon's
  children. Returns `:error` if any segment isn't a child of the one before.
  """
  @spec resolve_path([String.t()]) :: {:ok, [Taxon.t()]} | :error
  def resolve_path([]), do: {:ok, []}

  def resolve_path([first | rest]) do
    with %Taxon{} = genus <- get_genus(),
         %Taxon{} = first_taxon <- child_named(genus, first) do
      resolve_children(rest, first_taxon, [first_taxon])
    else
      _ -> :error
    end
  end

  defp resolve_children([], _parent, resolved), do: {:ok, Enum.reverse(resolved)}

  defp resolve_children([name | rest], parent, resolved) do
    case child_named(parent, name) do
      nil -> :error
      child -> resolve_children(rest, child, [child | resolved])
    end
  end

  defp child_named(parent, name) do
    Repo.get_by(Taxon, parent_id: parent.id, name: name)
  end

  # -- Species in taxon --

  @doc """
  Returns the species that sit directly in the taxon at the given path,
  i.e. not in one of its child taxa.

  The path is a list of taxon names encoding the hierarchy, e.g.
  `["Quercus", "Quercus"]` for section Quercus within subgenus Quercus
  (see `resolve_path/1`). An empty path returns the species placed directly
  in the genus or with no taxon at all. Unknown paths return an empty list.
  """
  @spec get_species_in_taxon([String.t()]) :: [SpeciesSchema.t()]
  def get_species_in_taxon([]) do
    case get_genus() do
      nil ->
        []

      genus ->
        from(s in SpeciesSchema,
          where: s.taxon_id == ^genus.id or is_nil(s.taxon_id),
          order_by: [asc: s.scientific_name]
        )
        |> Repo.all()
    end
  end

  def get_species_in_taxon(path) when is_list(path) do
    case resolve_path(path) do
      {:ok, taxa} -> species_directly_in(List.last(taxa))
      :error -> []
    end
  end

  defp species_directly_in(nil), do: []

  defp species_directly_in(%Taxon{id: id}) do
    from(s in SpeciesSchema,
      where: s.taxon_id == ^id,
      order_by: [asc: s.scientific_name]
    )
    |> Repo.all()
  end

  # -- Counts --

  @doc """
  Returns the total count of taxa.
  """
  @spec count() :: integer()
  def count do
    Repo.aggregate(Taxon, :count)
  end

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

  Every taxon but the genus needs a parent that ranks above it.
  """
  @spec create_taxon(map()) :: {:ok, Taxon.t()} | {:error, Ecto.Changeset.t()}
  def create_taxon(attrs) do
    %Taxon{}
    |> Taxon.changeset(attrs)
    |> validate_parent_rank()
    |> Repo.insert()
  end

  @doc """
  Updates a taxon with the given attributes.

  The level can't change after creation, and links to a taxon are keys, so a
  rename changes only this row. Changing the content stamps
  `content_updated_at` with today's date.
  """
  @spec update_taxon(Taxon.t(), map()) :: {:ok, Taxon.t()} | {:error, Ecto.Changeset.t()}
  def update_taxon(%Taxon{} = taxon, attrs) do
    taxon
    |> Taxon.changeset(Map.drop(attrs, ["level", :level]))
    |> validate_parent_rank()
    |> stamp_content_updated()
    |> Repo.update()
  end

  @doc """
  Checks the rank rule on a taxon changeset: only the genus has no parent,
  and every other taxon's parent ranks above it.

  `Oaks.Taxonomy` applies it on create and update, and the import's taxa
  hook applies it too.
  """
  @spec validate_parent_rank(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_parent_rank(changeset) do
    level = Ecto.Changeset.get_field(changeset, :level)
    parent_id = Ecto.Changeset.get_field(changeset, :parent_id)

    cond do
      level == @genus_level and is_nil(parent_id) ->
        changeset

      level == @genus_level ->
        Ecto.Changeset.add_error(changeset, :parent_id, "the genus has no parent")

      is_nil(parent_id) ->
        Ecto.Changeset.add_error(changeset, :parent_id, "is required for a #{level}")

      true ->
        check_parent_rank(changeset, parent_id, level)
    end
  end

  defp check_parent_rank(changeset, parent_id, level) do
    case get_taxon_by_id(parent_id) do
      nil -> Ecto.Changeset.add_error(changeset, :parent_id, "does not exist")
      parent -> require_rank_above(changeset, parent, level)
    end
  end

  defp require_rank_above(changeset, parent, level) do
    if level_rank(parent.level) < level_rank(level) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, :parent_id, "must rank above #{level}")
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
  Returns how many species and direct child taxa are in the taxon's subtree.
  """
  @spec taxon_usage(Taxon.t()) :: %{species: non_neg_integer(), children: non_neg_integer()}
  def taxon_usage(%Taxon{} = taxon) do
    ids = subtree_ids(taxon)

    %{
      species: Repo.aggregate(from(s in SpeciesSchema, where: s.taxon_id in ^ids), :count),
      children: Repo.aggregate(from(t in Taxon, where: t.parent_id == ^taxon.id), :count)
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
      parent_id: taxon.parent_id,
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

  defp maybe_filter_parent(query, parent_id) when is_integer(parent_id) do
    where(query, [t], t.parent_id == ^parent_id)
  end

  defp maybe_filter_parent(query, parent_id) when is_binary(parent_id) do
    case Integer.parse(parent_id) do
      {id, ""} -> where(query, [t], t.parent_id == ^id)
      _ -> query
    end
  end

  defp maybe_filter_parent(query, _parent_id), do: query

  defp parse_json(nil), do: nil
  defp parse_json(""), do: nil

  defp parse_json(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, data} -> data
      _ -> nil
    end
  end
end
