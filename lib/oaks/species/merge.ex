defmodule Oaks.Species.Merge do
  @moduledoc """
  Handles species merge (synonymization) operations.

  When a species is determined to be a synonym of another, this module
  transfers data from the source (synonym) to the target species and
  deletes the source. The entire operation runs in a transaction.
  """

  alias Ecto.Multi
  alias Oaks.Repo
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Species
  alias Oaks.Species.References
  alias Oaks.Species.Species, as: SpeciesSchema

  @scalar_fields ~w(author conservation_status subgenus section subsection complex parent1 parent2)a
  @list_fields [:hybrids, :closely_related_to, :subspecies_varieties]

  @doc """
  Returns a preview of what a merge would change.

  Loads both species with full source data and computes:
  - Field-by-field comparison of scalar fields
  - Source overlap (synonym-only, target-only, shared)
  - References from other species that point to the synonym
  - Target parents that point at the synonym (cleared by the merge)
  - Hybrids whose two parents are the synonym and the target
  - Names and links the synonym's lists add to the target
  - Synonyms that would be added

  Returns `{:ok, preview}` or `{:error, reason}`.
  """
  @spec preview_merge(String.t(), String.t()) ::
          {:ok, map()} | {:error, :source_not_found | :target_not_found | :same_species}
  def preview_merge(source_name, target_name) do
    with {:same, false} <- {:same, References.key(source_name) == References.key(target_name)},
         {:source, %SpeciesSchema{} = source} <-
           {:source, Species.get_species_full(source_name)},
         {:target, %SpeciesSchema{} = target} <-
           {:target, Species.get_species_full(target_name)} do
      {:ok, build_preview(source, target)}
    else
      {:same, true} -> {:error, :same_species}
      {:source, nil} -> {:error, :source_not_found}
      {:target, nil} -> {:error, :target_not_found}
    end
  end

  @doc """
  Executes a merge of the source species into the target species.

  `merge_opts` is a map with:
  - `"edited_fields"` - map of field name to value for target species updates
  - `"include_sources"` - list of source_ids to transfer from synonym to target

  The target gains the source's name and synonyms, its name lists (hybrids,
  closely related, subspecies & varieties) and external links, and the
  selected sources. Every other species' mention of the source is pointed at
  the target, and the source is deleted. All operations run in a single
  transaction via `Ecto.Multi`; on failure, all changes are rolled back.

  Returns `{:ok, target_species}` or `{:error, step, reason}`.
  """
  @spec execute_merge(String.t(), String.t(), map()) ::
          {:ok, SpeciesSchema.t()} | {:error, atom(), any()}
  @dialyzer {:no_opaque, execute_merge: 3}
  def execute_merge(source_name, target_name, merge_opts \\ %{}) do
    with false <- References.key(source_name) == References.key(target_name),
         source when not is_nil(source) <- Species.get_species_full(source_name),
         target when not is_nil(target) <- Species.get_species_full(target_name) do
      edited_fields = merge_opts["edited_fields"] || %{}
      include_source_ids = merge_opts["include_sources"] || []

      Multi.new()
      |> update_target_fields(target, source, edited_fields)
      |> transfer_sources(source, target, include_source_ids)
      |> References.rewrite(source.scientific_name, target.scientific_name,
        except: [source.id, target.id]
      )
      |> Multi.delete(:delete_source, source)
      |> Repo.transaction()
      |> handle_transaction_result(target_name)
    else
      true -> {:error, :load, "A species can't be merged into itself"}
      nil -> {:error, :load, "Species not found"}
    end
  end

  @doc """
  Finds species that reference the given name in relationship fields.

  Returns one `%{species: species, reference_type: field}` entry per field
  that mentions the name (see `Oaks.Species.References.find/1`).
  """
  @spec find_references(String.t()) :: [map()]
  def find_references(name) do
    for %{species: species, fields: fields} <- References.find(name),
        field <- fields,
        do: %{species: species, reference_type: Atom.to_string(field)}
  end

  # -- Preview helpers --

  defp build_preview(source, target) do
    source_source_ids = MapSet.new(source.species_sources, & &1.source_id)
    target_source_ids = MapSet.new(target.species_sources, & &1.source_id)

    synonym_only_ids = MapSet.difference(source_source_ids, target_source_ids)
    shared_ids = MapSet.intersection(source_source_ids, target_source_ids)
    target_only_ids = MapSet.difference(target_source_ids, source_source_ids)

    references =
      source.scientific_name
      |> find_references()
      |> Enum.reject(&(&1.species.id == target.id))

    %{
      source: source,
      target: target,
      field_comparisons: compare_scalar_fields(source, target),
      synonym_only_sources:
        Enum.filter(source.species_sources, &MapSet.member?(synonym_only_ids, &1.source_id)),
      shared_sources:
        Enum.filter(source.species_sources, &MapSet.member?(shared_ids, &1.source_id)),
      target_only_sources:
        Enum.filter(target.species_sources, &MapSet.member?(target_only_ids, &1.source_id)),
      references: references,
      self_reference_issues: detect_self_references(target, source.scientific_name),
      same_parent_hybrids: same_parent_hybrids(references, target),
      list_additions: list_additions(source, target),
      synonyms_to_add: compute_synonyms_to_add(source, target)
    }
  end

  defp compare_scalar_fields(source, target) do
    Enum.map(@scalar_fields, fn field ->
      source_val = Map.get(source, field)
      target_val = Map.get(target, field)

      %{
        field: field,
        source_value: source_val,
        target_value: target_val,
        differs: normalize_value(source_val) != normalize_value(target_val)
      }
    end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(val) when is_binary(val), do: String.trim(val)
  defp normalize_value(val), do: val

  @doc """
  Returns the target's parent fields that point at the synonym. After the
  merge they would point at the target itself, so the merge clears them.

  Pass the target with any edits applied to see what the merge will do.
  """
  @spec detect_self_references(map(), String.t()) :: [map()]
  def detect_self_references(target, synonym_name) do
    synonym = References.key(synonym_name)

    for field <- [:parent1, :parent2],
        value = Map.get(target, field),
        is_binary(value) and References.key(value) == synonym do
      %{
        field: Atom.to_string(field),
        value: value,
        hint: "This parent will be cleared, since it would point at the merged species itself."
      }
    end
  end

  # Hybrids whose parents are the synonym and the target end up with the
  # target as both parents.
  defp same_parent_hybrids(references, target) do
    target_key = References.key(target.scientific_name)

    references
    |> Enum.filter(&(&1.reference_type in ["parent1", "parent2"]))
    |> Enum.map(& &1.species)
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(fn hybrid ->
      Enum.any?(
        [hybrid.parent1, hybrid.parent2],
        &(is_binary(&1) and References.key(&1) == target_key)
      )
    end)
  end

  # Entries in the source's name lists and external links that the target
  # doesn't already have: %{field => [entry]} for non-empty fields only.
  defp list_additions(source, target) do
    for field <- @list_fields ++ [:external_links],
        current = References.decode(Map.get(target, field)),
        (merged = merged_list(field, source, target)) != current,
        into: %{} do
      {field, merged -- current}
    end
  end

  defp merged_list(:external_links, source, target) do
    (References.decode(target.external_links) ++ References.decode(source.external_links))
    |> Enum.uniq_by(&link_key/1)
  end

  defp merged_list(field, source, target) do
    drop = MapSet.new([source.scientific_name, target.scientific_name], &References.key/1)

    (References.decode(Map.get(target, field)) ++ References.decode(Map.get(source, field)))
    |> Enum.reject(&(is_binary(&1) and MapSet.member?(drop, References.key(&1))))
    |> Enum.uniq_by(&entry_key/1)
  end

  defp link_key(%{"url" => url}) when is_binary(url), do: String.trim_trailing(url, "/")
  defp link_key(link), do: link

  defp entry_key(entry) when is_binary(entry), do: References.key(entry)
  defp entry_key(%{"name" => name}) when is_binary(name), do: References.key(name)
  defp entry_key(entry), do: entry

  defp compute_synonyms_to_add(source, target) do
    existing =
      MapSet.new(References.decode(target.synonyms) ++ [target.scientific_name], &entry_key/1)

    ([source.scientific_name] ++ References.decode(source.synonyms))
    |> Enum.reject(&MapSet.member?(existing, entry_key(&1)))
    |> Enum.uniq_by(&entry_key/1)
  end

  # -- Multi steps --

  @spec update_target_fields(Multi.t(), SpeciesSchema.t(), SpeciesSchema.t(), map()) :: Multi.t()
  @dialyzer {:no_opaque, update_target_fields: 4}
  defp update_target_fields(multi, target, source, edited_fields) do
    merged_away = MapSet.new([source.scientific_name, target.scientific_name], &References.key/1)

    scalars =
      Map.new(@scalar_fields, fn field ->
        value = Map.get(edited_fields, Atom.to_string(field), Map.get(target, field))

        # A parent naming either species would make the target its own parent.
        value =
          if field in [:parent1, :parent2] and is_binary(value) and
               MapSet.member?(merged_away, References.key(value)),
             do: nil,
             else: value

        {field, value}
      end)

    lists =
      Map.new(@list_fields ++ [:external_links], fn field ->
        {field, References.encode(merged_list(field, source, target))}
      end)

    synonyms =
      References.encode(
        References.decode(target.synonyms) ++ compute_synonyms_to_add(source, target)
      )

    attrs = scalars |> Map.merge(lists) |> Map.put(:synonyms, synonyms)

    Multi.update(multi, :update_target, SpeciesSchema.changeset(target, attrs))
  end

  defp transfer_sources(multi, source, target, include_source_ids) do
    target_source_ids = MapSet.new(target.species_sources, & &1.source_id)
    target_has_preferred = Enum.any?(target.species_sources, & &1.is_preferred)

    sources_to_transfer =
      source.species_sources
      |> Enum.filter(fn ss ->
        ss.source_id in include_source_ids &&
          not MapSet.member?(target_source_ids, ss.source_id)
      end)

    Enum.reduce(sources_to_transfer, multi, fn ss, acc ->
      attrs = %{
        species_id: target.id,
        source_id: ss.source_id,
        local_names: ss.local_names,
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
        url: ss.url,
        # Keep the synonym's preferred source unless the target already has one.
        is_preferred: ss.is_preferred and not target_has_preferred
      }

      step_name = {:transfer_source, ss.source_id}
      Multi.insert(acc, step_name, SpeciesSource.changeset(%SpeciesSource{}, attrs))
    end)
  end

  defp handle_transaction_result({:ok, _changes}, target_name) do
    target = Species.get_species_full(target_name)
    {:ok, target}
  end

  defp handle_transaction_result({:error, step, changeset, _changes}, _target_name) do
    {:error, step, changeset}
  end
end
