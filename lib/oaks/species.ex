defmodule Oaks.Species do
  @moduledoc """
  The Species context.

  Provides functions for querying and managing species records,
  including their relationships to sources, taxonomy, and hybrids.
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species

  @default_limit 50
  @max_limit 500

  # -- List --

  @doc """
  Returns all species matching the given filters, ordered by scientific_name.

  No pagination — intended for the LiveView list page.

  ## Options
    * `"search"` - case-insensitive name search
    * `"subgenus"`, `"section"`, `"subsection"`, `"complex"` - taxonomy filters
    * `"hybrid"` - filter by hybrid status
  """
  @spec list_all_species(map()) :: [Species.t()]
  def list_all_species(params \\ %{}) do
    params
    |> species_filter_query()
    |> maybe_filter_search(params["search"])
    |> order_by([s], asc: s.scientific_name)
    |> Repo.all()
  end

  @doc """
  Returns distinct non-nil subgenus values, sorted alphabetically.
  """
  @spec distinct_subgenera() :: [String.t()]
  def distinct_subgenera do
    from(s in Species,
      select: s.subgenus,
      distinct: true,
      where: not is_nil(s.subgenus),
      order_by: [asc: s.subgenus]
    )
    |> Repo.all()
  end

  @doc """
  Returns distinct non-nil section values, sorted alphabetically.
  """
  @spec distinct_sections() :: [String.t()]
  def distinct_sections do
    from(s in Species,
      select: s.section,
      distinct: true,
      where: not is_nil(s.section),
      order_by: [asc: s.section]
    )
    |> Repo.all()
  end

  @doc """
  Returns a paginated list of species with optional filters.

  ## Options
    * `:limit` - max results (default 50, max 500)
    * `:offset` - skip N results (default 0)
    * `:subgenus`, `:section`, `:subsection`, `:complex` - filter by taxonomy
    * `:hybrid` - filter by hybrid status (boolean)
  """
  @spec list_species(map()) :: {[Species.t()], integer()}
  def list_species(params \\ %{}) do
    limit = clamp_limit(params["limit"])
    offset = parse_int(params["offset"]) || 0

    base = species_filter_query(params)
    count = Repo.aggregate(base, :count)

    results =
      base
      |> order_by([s], asc: s.scientific_name)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    {results, count}
  end

  @doc """
  Returns a species by scientific name, or nil if not found.
  """
  @spec get_species_by_name(String.t()) :: Species.t() | nil
  def get_species_by_name(name) do
    Repo.get_by(Species, scientific_name: name)
  end

  @doc """
  Returns a species by ID, or nil if not found.
  """
  @spec get_species(integer()) :: Species.t() | nil
  def get_species(id) do
    Repo.get(Species, id)
  end

  @doc """
  Returns a species with all source data preloaded.

  Sources are ordered with preferred source first.
  """
  @spec get_species_full(String.t()) :: Species.t() | nil
  def get_species_full(name) do
    case Repo.get_by(Species, scientific_name: name) do
      nil ->
        nil

      species ->
        Repo.preload(species,
          species_sources:
            from(ss in SpeciesSource,
              join: s in Source,
              on: s.id == ss.source_id,
              order_by: [desc: ss.is_preferred],
              preload: [source: s]
            )
        )
    end
  end

  @doc """
  Searches species by name. Case-insensitive LIKE match.
  """
  @spec search_species(String.t(), integer()) :: [Species.t()]
  def search_species(query, limit \\ @default_limit) do
    limit = min(limit, @max_limit)
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      where: fragment("lower(?) LIKE ?", s.scientific_name, ^search_term),
      order_by: [asc: s.scientific_name],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Finds species that reference the given name as a synonym.
  """
  @spec find_synonym(String.t()) :: Species.t() | nil
  def find_synonym(name) do
    search = "%\"#{name}\"%"

    from(s in Species,
      where: fragment("? LIKE ?", s.synonyms, ^search),
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns the total count of species.
  """
  @spec count() :: integer()
  def count do
    Repo.aggregate(Species, :count)
  end

  @doc """
  Returns the count of hybrid species.
  """
  @spec count_hybrids() :: integer()
  def count_hybrids do
    from(s in Species, where: s.is_hybrid == true)
    |> Repo.aggregate(:count)
  end

  @doc """
  Given a list of hybrid scientific names, returns a list of maps with
  `name`, `parent1`, and `parent2` for each hybrid.
  """
  @spec get_hybrids_with_parents([String.t()]) :: [map()]
  def get_hybrids_with_parents([]), do: []

  def get_hybrids_with_parents(hybrid_names) do
    parent_map =
      from(s in Species,
        where: s.scientific_name in ^hybrid_names,
        select: {s.scientific_name, s.parent1, s.parent2}
      )
      |> Repo.all()
      |> Map.new(fn {name, p1, p2} -> {name, {p1, p2}} end)

    Enum.map(hybrid_names, fn name ->
      {p1, p2} = Map.get(parent_map, name, {nil, nil})
      %{name: name, parent1: p1, parent2: p2}
    end)
  end

  # -- Write operations --

  @doc """
  Returns a changeset for tracking species changes.
  """
  @spec change_species(Species.t(), map()) :: Ecto.Changeset.t()
  def change_species(%Species{} = species, attrs \\ %{}) do
    Species.changeset(species, attrs)
  end

  @doc """
  Creates a species.

  Returns `{:ok, species}` on success, `{:error, changeset}` on failure.
  """
  @spec create_species(map()) :: {:ok, Species.t()} | {:error, Ecto.Changeset.t()}
  def create_species(attrs) do
    %Species{}
    |> Species.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a species.

  Returns `{:ok, species}` on success, `{:error, changeset}` on failure.
  """
  @spec update_species(Species.t(), map()) :: {:ok, Species.t()} | {:error, Ecto.Changeset.t()}
  def update_species(%Species{} = species, attrs) do
    species
    |> Species.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a species.

  Species_sources records are deleted via ON DELETE CASCADE in the database.
  Returns `{:ok, species}` on success, `{:error, changeset}` on failure.
  """
  @spec delete_species(Species.t()) :: {:ok, Species.t()} | {:error, Ecto.Changeset.t()}
  def delete_species(%Species{} = species) do
    Repo.delete(species)
  end

  # -- Serialization helpers --

  @doc """
  Converts a species struct to an API response map.
  """
  @spec to_map(Species.t()) :: map()
  def to_map(species) do
    %{
      id: species.id,
      scientific_name: species.scientific_name,
      author: species.author,
      is_hybrid: species.is_hybrid,
      conservation_status: species.conservation_status,
      subgenus: species.subgenus,
      section: species.section,
      subsection: species.subsection,
      complex: species.complex,
      parent1: species.parent1,
      parent2: species.parent2,
      hybrids: parse_json_array(species.hybrids),
      closely_related_to: parse_json_array(species.closely_related_to),
      subspecies_varieties: parse_json_array(species.subspecies_varieties),
      synonyms: parse_json_array(species.synonyms),
      external_links: parse_json_array(species.external_links)
    }
  end

  @doc """
  Converts a species with preloaded sources to a full API response map.
  """
  @spec to_full_map(Species.t()) :: map()
  def to_full_map(species) do
    base = to_map(species)

    sources =
      Enum.map(species.species_sources, fn ss ->
        %{
          source_id: ss.source.id,
          source_name: ss.source.name,
          source_url: ss.source.url,
          is_preferred: ss.is_preferred,
          local_names: parse_json_array(ss.local_names),
          range: ss.range,
          growth_habit: ss.growth_habit,
          leaves: ss.leaves,
          flowers: ss.flowers,
          fruits: ss.fruits,
          bark: ss.bark,
          twigs: ss.twigs,
          buds: ss.buds,
          hardiness_habitat: ss.hardiness_habitat,
          miscellaneous: ss.miscellaneous,
          url: ss.url
        }
      end)

    Map.put(base, :sources, sources)
  end

  # -- Private --

  defp species_filter_query(params) do
    Species
    |> maybe_filter(:subgenus, params["subgenus"])
    |> maybe_filter(:section, params["section"])
    |> maybe_filter(:subsection, params["subsection"])
    |> maybe_filter(:complex, params["complex"])
    |> maybe_filter_hybrid(params["hybrid"])
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, _field, ""), do: query

  defp maybe_filter(query, field, value) do
    where(query, [s], field(s, ^field) == ^value)
  end

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) do
    search_term = "%#{String.downcase(search)}%"
    where(query, [s], fragment("lower(?) LIKE ?", s.scientific_name, ^search_term))
  end

  defp maybe_filter_hybrid(query, nil), do: query
  defp maybe_filter_hybrid(query, ""), do: query

  defp maybe_filter_hybrid(query, value) when is_binary(value) do
    case value do
      v when v in ["true", "1"] -> where(query, [s], s.is_hybrid == true)
      v when v in ["false", "0"] -> where(query, [s], s.is_hybrid == false)
      _ -> query
    end
  end

  defp clamp_limit(nil), do: @default_limit

  defp clamp_limit(val) do
    case parse_int(val) do
      nil -> @default_limit
      n when n < 1 -> @default_limit
      n when n > @max_limit -> @max_limit
      n -> n
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @doc false
  def parse_json_array(nil), do: []
  def parse_json_array(""), do: []

  def parse_json_array(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end
end
