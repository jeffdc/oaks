defmodule Oaks.Species do
  @moduledoc """
  The Species context.

  Provides functions for querying and managing species records,
  including their relationships to sources, taxonomy, and hybrids.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Oaks.Images
  alias Oaks.Repo
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.References
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
    offset = clamp_offset(params["offset"])

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
    limit = clamp_limit(limit)
    search_term = like_pattern(query)

    from(s in Species,
      where: fragment("lower(?) LIKE ? ESCAPE '\\'", s.scientific_name, ^search_term),
      order_by: [asc: s.scientific_name],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Finds the species that lists the given name as a synonym.

  Synonym entries often carry authorship (e.g. `"handeliana A.Camus"`), so an
  entry matches when it equals the name exactly or when the name is followed by
  an author citation (a word starting with an uppercase letter or `(`). Entries
  that continue with a rank or further epithet (`"reticulata var. retifolia"`)
  do not match a lookup for `"reticulata"`. Exact matches win over
  author-suffixed ones; ties go to the lowest species id.
  """
  @spec find_synonym(String.t()) :: Species.t() | nil
  def find_synonym(name) do
    target = normalize_synonym_name(name)

    case String.split(target) do
      [] ->
        nil

      words ->
        words
        |> List.last()
        |> synonym_candidates()
        |> Enum.map(&{best_synonym_match(&1, target), &1})
        |> Enum.reject(fn {rank, _species} -> is_nil(rank) end)
        |> Enum.min_by(fn {rank, _species} -> rank end, fn -> {nil, nil} end)
        |> elem(1)
    end
  end

  # Coarse SQL prefilter on one word of the name; exact matching happens in Elixir.
  defp synonym_candidates(word) do
    search = "%#{escape_like(word)}%"

    from(s in Species,
      where: fragment("lower(?) LIKE ? ESCAPE '\\'", s.synonyms, ^search),
      order_by: s.id
    )
    |> Repo.all()
  end

  # Returns 0 for an exact match, 1 for name + author, nil for no match.
  defp best_synonym_match(species, target) do
    species.synonyms
    |> parse_json_array()
    |> Enum.map(&synonym_match_rank(&1, target))
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp synonym_match_rank(%{"name" => name}, target) when is_binary(name) do
    if normalize_synonym_name(name) == target, do: 0
  end

  defp synonym_match_rank(entry, target) when is_binary(entry) do
    entry = String.trim(entry)
    normalized = normalize_synonym_name(entry)

    cond do
      normalized == target -> 0
      String.starts_with?(normalized, target <> " ") and author_follows?(entry, target) -> 1
      true -> nil
    end
  end

  defp synonym_match_rank(_entry, _target), do: nil

  # Checks the original-case text after the name to see if it starts like an
  # author citation rather than a rank marker or another epithet.
  defp author_follows?(entry, target) do
    rest =
      entry
      |> String.split()
      |> strip_name_prefix()
      |> Enum.drop(length(String.split(target)))

    case rest do
      [word | _] -> Regex.match?(~r/^[(\p{Lu}]/u, word)
      [] -> false
    end
  end

  defp strip_name_prefix(["Quercus" | rest]), do: strip_name_prefix(rest)
  defp strip_name_prefix(["×" | rest]), do: rest
  defp strip_name_prefix(["×" <> word | rest]) when word != "", do: [word | rest]
  defp strip_name_prefix(words), do: words

  defp normalize_synonym_name(name) do
    name
    |> String.split()
    |> strip_name_prefix()
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp escape_like(str) do
    String.replace(str, ~r/[\\%_]/, fn char -> "\\" <> char end)
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

  @ranks ~w(subgenus section subsection complex)a

  @doc """
  Returns where a species sits under the genus, outermost first: its
  subgenus, section, subsection and complex as stored (those it has), then,
  for a variety or subspecies, the species it belongs to. Each entry is a
  map with `level`, `name` and `hybrid` (true only for a named hybrid's
  species, as in `"× kerneri montserratii"`).

  A hybrid with none of the four ranks stored sits where both its parents
  do: the ranks the two parents share, from the subgenus down, stopping at
  the first they don't (`"× albescens"`, `ilex × pubescens`, sits in the
  genus only). A formula hybrid's stored ranks already are those.

  A variety is any name of more than one word that isn't a formula
  (`"acutissima kingii"`); its species is the first word, with a named
  hybrid's sign, when that species exists.
  """
  @spec placement(Species.t()) :: [%{level: String.t(), name: String.t(), hybrid: boolean()}]
  def placement(%Species{} = species) do
    stored = stored_ranks(species)
    ranks = if stored == [] and species.is_hybrid, do: shared_parent_ranks(species), else: stored

    Enum.map(ranks, fn {level, name} -> %{level: to_string(level), name: name, hybrid: false} end) ++
      parent_species(species)
  end

  defp stored_ranks(species) do
    for level <- @ranks, (name = Map.get(species, level)) not in [nil, ""], do: {level, name}
  end

  defp shared_parent_ranks(%Species{parent1: p1, parent2: p2})
       when is_binary(p1) and is_binary(p2) do
    case Repo.all(from(s in Species, where: s.scientific_name in ^[p1, p2])) do
      [a, b] ->
        @ranks
        |> Enum.map(&{&1, Map.get(a, &1), Map.get(b, &1)})
        |> Enum.take_while(fn {_level, x, y} -> x not in [nil, ""] and x == y end)
        |> Enum.map(fn {level, name, _} -> {level, name} end)

      _ ->
        []
    end
  end

  defp shared_parent_ranks(_species), do: []

  defp parent_species(%Species{scientific_name: name}) do
    with false <- String.match?(name, ~r/\S\s*×/u),
         [_, sign, first, _rest] <- Regex.run(~r/^(×\s*)?(\S+)\s+(.+)$/u, name),
         parent when not is_nil(parent) <- get_species_by_name(sign <> first) do
      [%{level: "species", name: parent.scientific_name, hybrid: parent.is_hybrid}]
    else
      _ -> []
    end
  end

  # -- Source text: the data display contract (docs/species-photos-plan.md, Phase 4) --

  @oak_compendium 3
  @oaks_of_the_world 2

  @text_fields ~w(range growth_habit leaves flowers fruits bark twigs buds hardiness_habitat miscellaneous)a

  @doc """
  Returns a species' source rows in the source order: the row marked
  preferred, then Oak Compendium, then Oaks of the World, then the rest by
  the source's name (ties by id, so the order is stable). Each row needs
  its `source` preloaded, as `get_species_full/1` does.

  The species page shows its tabs in this order and opens the first with
  any text (`default_source/1`); the title's common name is the first
  nonempty one in it (`common_name/1`). "Preferred" only decides the order;
  it is never shown.
  """
  @spec ordered_sources([SpeciesSource.t()]) :: [SpeciesSource.t()]
  def ordered_sources(species_sources) do
    Enum.sort_by(species_sources, fn ss ->
      rank =
        cond do
          ss.is_preferred -> 0
          ss.source_id == @oak_compendium -> 1
          ss.source_id == @oaks_of_the_world -> 2
          true -> 3
        end

      {rank, String.downcase(ss.source.name), ss.source_id}
    end)
  end

  @doc """
  Returns the row a species page opens on: the first in `rows` (already in
  the source order) with any text, or the first row when none has any; nil
  for no rows.
  """
  @spec default_source([SpeciesSource.t()]) :: SpeciesSource.t() | nil
  def default_source(rows), do: Enum.find(rows, &has_text?/1) || List.first(rows)

  @doc """
  Whether a source row has any text: a common name or a nonempty field.
  Blank and whitespace-only values don't count.
  """
  @spec has_text?(SpeciesSource.t()) :: boolean()
  def has_text?(%SpeciesSource{} = ss) do
    common_names(ss) != [] or Enum.any?(@text_fields, &present?(Map.get(ss, &1)))
  end

  @doc """
  Returns a source row's common names: its stored list, without blank
  entries, trimmed.
  """
  @spec common_names(SpeciesSource.t()) :: [String.t()]
  def common_names(%SpeciesSource{local_names: names}) do
    names |> parse_name_list() |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Returns the common name for a species' title, with the row that supplies
  it: the first name of the first row in `rows` (already in the source
  order) that has one; nil when none does.
  """
  @spec common_name([SpeciesSource.t()]) :: {String.t(), SpeciesSource.t()} | nil
  def common_name(rows) do
    Enum.find_value(rows, fn ss ->
      case common_names(ss) do
        [name | _] -> {name, ss}
        [] -> nil
      end
    end)
  end

  @doc """
  Whether the Oak Compendium covers a species: its Oak Compendium row has
  any text. A taxon it doesn't cover gets the not-covered notice.
  """
  @spec covered?([SpeciesSource.t()]) :: boolean()
  def covered?(species_sources) do
    Enum.any?(species_sources, &(&1.source_id == @oak_compendium and has_text?(&1)))
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  @doc """
  Returns a species' hybrids, each with its other parent: maps with
  `name` and `other` (the hybrid's parent that isn't this species, without
  its genus or sign; nil when it isn't recorded), in the stored order.
  """
  @spec hybrids_with_other_parent(Species.t()) :: [%{name: String.t(), other: String.t() | nil}]
  def hybrids_with_other_parent(%Species{} = species) do
    current = bare_name(species.scientific_name)

    species.hybrids
    |> parse_name_list()
    |> get_hybrids_with_parents()
    |> Enum.map(fn hybrid ->
      other =
        [hybrid.parent1, hybrid.parent2]
        |> Enum.map(&bare_name/1)
        |> Enum.find(&(&1 != "" and String.downcase(&1) != String.downcase(current)))

      %{name: hybrid.name, other: other}
    end)
  end

  defp bare_name(name) do
    (name || "")
    |> String.replace(~r/^Quercus\s+/, "")
    |> String.replace(~r/^×\s*/, "")
    |> String.trim()
  end

  @doc """
  Returns the taxa beside a species in its group, for the siblings menu of
  the taxonomy band: `%{level: level, name: name, names: names}`, where the
  group is the last entry of `placement/1` and `names` are, for a rank
  (subgenus to complex), the species stored at it (not hybrids, varieties
  or subspecies) and, for a variety's species, that species' varieties and
  subspecies; sorted by name. The species itself is among them unless it
  is a hybrid. Nil when it has no group, or nothing else is in it.
  """
  @spec siblings(Species.t()) ::
          %{level: String.t(), name: String.t(), names: [String.t()]} | nil
  def siblings(%Species{} = species) do
    case List.last(placement(species)) do
      nil ->
        nil

      %{level: level, name: name} ->
        names = sibling_names(level, name)

        if Enum.any?(names, &(&1 != species.scientific_name)),
          do: %{level: level, name: name, names: names},
          else: nil
    end
  end

  defp sibling_names("species", name) do
    pattern = escape_like(name) <> " %"

    from(s in Species,
      where: fragment("? LIKE ? ESCAPE '\\'", s.scientific_name, ^pattern),
      where: s.is_hybrid == false and not like(s.scientific_name, "%×%"),
      order_by: s.scientific_name,
      select: s.scientific_name
    )
    |> Repo.all()
  end

  defp sibling_names(level, name) do
    field = String.to_existing_atom(level)

    from(s in Species,
      where: field(s, ^field) == ^name,
      where: s.is_hybrid == false and not like(s.scientific_name, "% %"),
      order_by: s.scientific_name,
      select: s.scientific_name
    )
    |> Repo.all()
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

  Renaming also points every other species' mention of the old name at the
  new one (see `Oaks.Species.References`) and keeps the old name as a
  synonym so existing links still resolve, all in one transaction.

  Returns `{:ok, species}` on success, `{:error, changeset}` on failure.
  """
  @spec update_species(Species.t(), map()) :: {:ok, Species.t()} | {:error, Ecto.Changeset.t()}
  def update_species(%Species{} = species, attrs) do
    changeset = Species.changeset(species, attrs)

    case Ecto.Changeset.fetch_change(changeset, :scientific_name) do
      {:ok, new_name} when changeset.valid? ->
        if References.key(new_name) == References.key(species.scientific_name),
          do: Repo.update(changeset),
          else: rename_species(species, changeset, new_name)

      _ ->
        Repo.update(changeset)
    end
  end

  defp rename_species(species, changeset, new_name) do
    old_name = species.scientific_name

    synonyms = References.decode(Ecto.Changeset.get_field(changeset, :synonyms))

    known? =
      Enum.any?(synonyms, &(is_binary(&1) and References.key(&1) == References.key(old_name)))

    changeset =
      if known?,
        do: changeset,
        else:
          Ecto.Changeset.put_change(
            changeset,
            :synonyms,
            References.encode(synonyms ++ [old_name])
          )

    Multi.new()
    |> Multi.update(:species, changeset)
    |> References.rewrite(old_name, new_name, except: [species.id])
    |> Repo.transaction()
    |> case do
      {:ok, %{species: updated}} -> {:ok, updated}
      {:error, :species, changeset, _} -> {:error, changeset}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns the other species that mention this species by name, with the
  fields that mention it (see `Oaks.Species.References.find/1`).
  """
  @spec references_to(Species.t()) :: [References.mention()]
  def references_to(%Species{} = species), do: References.find(species.scientific_name)

  @doc """
  Deletes a species and removes its name from every other species that
  mentions it, in one transaction.

  Species_sources records are deleted via ON DELETE CASCADE in the database.
  Its photos are removed by `Oaks.Images.delete_species_images/2` in the same
  transaction, which records their files for cleanup after it commits.
  Returns `{:ok, species}` on success, `{:error, changeset}` on failure.
  """
  @spec delete_species(Species.t()) :: {:ok, Species.t()} | {:error, Ecto.Changeset.t()}
  def delete_species(%Species{} = species) do
    Multi.new()
    |> References.rewrite(species.scientific_name, nil, except: [species.id])
    |> Images.delete_species_images(species)
    |> Multi.delete(:species, species)
    |> Repo.transaction()
    |> case do
      {:ok, %{species: deleted}} -> {:ok, deleted}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
    end
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

  defp maybe_filter(query, _field, ""), do: query

  defp maybe_filter(query, field, value) when is_binary(value) do
    where(query, [s], field(s, ^field) == ^value)
  end

  defp maybe_filter(query, _field, _value), do: query

  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) when is_binary(search) do
    search_term = like_pattern(search)
    where(query, [s], fragment("lower(?) LIKE ? ESCAPE '\\'", s.scientific_name, ^search_term))
  end

  defp maybe_filter_search(query, _search), do: query

  defp maybe_filter_hybrid(query, nil), do: query
  defp maybe_filter_hybrid(query, ""), do: query

  defp maybe_filter_hybrid(query, value) when is_binary(value) do
    case value do
      v when v in ["true", "1"] -> where(query, [s], s.is_hybrid == true)
      v when v in ["false", "0"] -> where(query, [s], s.is_hybrid == false)
      _ -> query
    end
  end

  defp maybe_filter_hybrid(query, _value), do: query

  @doc """
  Parses a requested page size, defaulting to #{@default_limit} and capping at #{@max_limit}.
  """
  @spec clamp_limit(term()) :: pos_integer()
  def clamp_limit(val) do
    case parse_int(val) do
      nil -> @default_limit
      n when n < 1 -> @default_limit
      n when n > @max_limit -> @max_limit
      n -> n
    end
  end

  @doc """
  Parses a requested offset, defaulting to 0 and never negative.
  """
  @spec clamp_offset(term()) :: non_neg_integer()
  def clamp_offset(val), do: max(parse_int(val) || 0, 0)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(_val), do: nil

  defp like_pattern(term), do: "%#{escape_like(String.downcase(term))}%"

  @doc """
  Parses a JSON list of names, keeping only string entries so malformed
  stored data can't crash callers that treat entries as names.
  """
  @spec parse_name_list(String.t() | nil) :: [String.t()]
  def parse_name_list(value), do: value |> parse_json_array() |> Enum.filter(&is_binary/1)

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
