defmodule OakCompendium.Species.Merge do
  @moduledoc """
  Handles species merge (synonymization) operations.

  When a species is determined to be a synonym of another, this module
  transfers data from the source (synonym) to the target species and
  deletes the source. The entire operation runs in a transaction.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias OakCompendium.Repo
  alias OakCompendium.Sources.SpeciesSource
  alias OakCompendium.Species
  alias OakCompendium.Species.Species, as: SpeciesSchema

  @scalar_fields ~w(author conservation_status subgenus section subsection complex parent1 parent2)a

  @doc """
  Returns a preview of what a merge would change.

  Loads both species with full source data and computes:
  - Field-by-field comparison of scalar fields
  - Source overlap (synonym-only, target-only, shared)
  - References from other species that point to the synonym
  - Self-reference issues on the target
  - Synonyms that would be added

  Returns `{:ok, preview}` or `{:error, reason}`.
  """
  @spec preview_merge(String.t(), String.t()) ::
          {:ok, map()} | {:error, :source_not_found | :target_not_found | :same_species}
  def preview_merge(source_name, target_name) do
    if String.downcase(source_name) == String.downcase(target_name) do
      {:error, :same_species}
    else
      with source when not is_nil(source) <- Species.get_species_full(source_name),
           target when not is_nil(target) <- Species.get_species_full(target_name) do
        {:ok, build_preview(source, target)}
      else
        nil -> {:error, :source_not_found}
      end
    end
  end

  @doc """
  Executes a merge of the source species into the target species.

  `merge_opts` is a map with:
  - `"edited_fields"` - map of field name to value for target species updates
  - `"include_sources"` - list of source_ids to transfer from synonym to target

  All operations run in a single transaction via `Ecto.Multi`.
  On failure, all changes are rolled back.

  Returns `{:ok, target_species}` or `{:error, step, reason}`.
  """
  @spec execute_merge(String.t(), String.t(), map()) ::
          {:ok, SpeciesSchema.t()} | {:error, atom(), any()}
  def execute_merge(source_name, target_name, merge_opts \\ %{}) do
    with source when not is_nil(source) <- Species.get_species_full(source_name),
         target when not is_nil(target) <- Species.get_species_full(target_name) do
      edited_fields = merge_opts["edited_fields"] || %{}
      include_source_ids = merge_opts["include_sources"] || []

      Multi.new()
      |> update_target_fields(target, source, edited_fields)
      |> transfer_sources(source, target, include_source_ids)
      |> update_references(source, target)
      |> delete_source(source)
      |> Repo.transaction()
      |> handle_transaction_result(target_name)
    else
      nil -> {:error, :load, "Species not found"}
    end
  end

  @doc """
  Finds species that reference the given name in relationship fields.

  Searches parent1, parent2, hybrids, and closely_related_to.
  Returns a list of `{species, reference_type}` tuples grouped by type.
  """
  @spec find_references(String.t()) :: [map()]
  def find_references(name) do
    lower_name = String.downcase(name)
    json_pattern = "%\"#{name}\"%"

    parent_refs =
      from(s in SpeciesSchema,
        where:
          fragment("lower(?)", s.parent1) == ^lower_name or
            fragment("lower(?)", s.parent2) == ^lower_name,
        select: s
      )
      |> Repo.all()
      |> Enum.flat_map(fn s ->
        refs = []

        refs =
          if s.parent1 && String.downcase(s.parent1) == lower_name,
            do: [%{species: s, reference_type: "parent1"} | refs],
            else: refs

        refs =
          if s.parent2 && String.downcase(s.parent2) == lower_name,
            do: [%{species: s, reference_type: "parent2"} | refs],
            else: refs

        refs
      end)

    hybrid_refs =
      from(s in SpeciesSchema,
        where: fragment("? LIKE ?", s.hybrids, ^json_pattern)
      )
      |> Repo.all()
      |> Enum.filter(fn s ->
        s.hybrids
        |> Species.parse_json_array()
        |> Enum.any?(&(String.downcase(&1) == lower_name))
      end)
      |> Enum.map(&%{species: &1, reference_type: "hybrids"})

    related_refs =
      from(s in SpeciesSchema,
        where: fragment("? LIKE ?", s.closely_related_to, ^json_pattern)
      )
      |> Repo.all()
      |> Enum.filter(fn s ->
        s.closely_related_to
        |> Species.parse_json_array()
        |> Enum.any?(&(String.downcase(&1) == lower_name))
      end)
      |> Enum.map(&%{species: &1, reference_type: "closely_related_to"})

    parent_refs ++ hybrid_refs ++ related_refs
  end

  # -- Preview helpers --

  defp build_preview(source, target) do
    source_source_ids = MapSet.new(source.species_sources, & &1.source_id)
    target_source_ids = MapSet.new(target.species_sources, & &1.source_id)

    synonym_only_ids = MapSet.difference(source_source_ids, target_source_ids)
    shared_ids = MapSet.intersection(source_source_ids, target_source_ids)
    target_only_ids = MapSet.difference(target_source_ids, source_source_ids)

    references = find_references(source.scientific_name)
    self_ref_issues = detect_self_references(target, source.scientific_name)
    synonyms_to_add = compute_synonyms_to_add(source, target)

    %{
      source: source,
      target: target,
      field_comparisons: compare_scalar_fields(source, target),
      synonym_only_sources:
        Enum.filter(source.species_sources, &MapSet.member?(synonym_only_ids, &1.source_id)),
      shared_sources: MapSet.to_list(shared_ids),
      target_only_sources:
        Enum.filter(target.species_sources, &MapSet.member?(target_only_ids, &1.source_id)),
      references: references,
      self_reference_issues: self_ref_issues,
      synonyms_to_add: synonyms_to_add
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
  Detects self-reference issues that would occur if the synonym is merged
  into the target. Returns a list of issue maps.
  """
  @spec detect_self_references(SpeciesSchema.t(), String.t()) :: [map()]
  def detect_self_references(target, synonym_name) do
    lower_synonym = synonym_name |> String.downcase() |> String.replace(~r/^×\s*/, "")
    issues = []

    matches? = fn name ->
      name && name |> String.downcase() |> String.replace(~r/^×\s*/, "") == lower_synonym
    end

    issues =
      if matches?.(target.parent1) do
        [%{field: "parent1", value: target.parent1, hint: "Clear the parent1 field"} | issues]
      else
        issues
      end

    issues =
      if matches?.(target.parent2) do
        [%{field: "parent2", value: target.parent2, hint: "Clear the parent2 field"} | issues]
      else
        issues
      end

    hybrids = Species.parse_json_array(target.hybrids)

    issues =
      Enum.reduce(hybrids, issues, fn h, acc ->
        if matches?.(h) do
          [
            %{field: "hybrids", value: h, hint: "Remove from target's hybrids before merging"}
            | acc
          ]
        else
          acc
        end
      end)

    related = Species.parse_json_array(target.closely_related_to)

    issues =
      Enum.reduce(related, issues, fn r, acc ->
        if matches?.(r) do
          [
            %{
              field: "closely_related_to",
              value: r,
              hint: "Remove from target's closely related species"
            }
            | acc
          ]
        else
          acc
        end
      end)

    Enum.reverse(issues)
  end

  defp compute_synonyms_to_add(source, target) do
    existing =
      target.synonyms
      |> Species.parse_json_array()
      |> MapSet.new(&String.downcase/1)

    source_synonyms = Species.parse_json_array(source.synonyms)

    new_synonyms =
      if MapSet.member?(existing, String.downcase(source.scientific_name)) do
        []
      else
        [source.scientific_name]
      end

    new_synonyms ++
      Enum.reject(source_synonyms, &MapSet.member?(existing, String.downcase(&1)))
  end

  # -- Multi steps --

  defp update_target_fields(multi, target, source, edited_fields) do
    synonyms_to_add = compute_synonyms_to_add(source, target)

    existing_synonyms = Species.parse_json_array(target.synonyms)
    updated_synonyms = Jason.encode!(existing_synonyms ++ synonyms_to_add)

    attrs =
      @scalar_fields
      |> Enum.reduce(%{}, fn field, acc ->
        field_str = Atom.to_string(field)

        value =
          if Map.has_key?(edited_fields, field_str) do
            edited_fields[field_str]
          else
            Map.get(target, field)
          end

        Map.put(acc, field, value)
      end)
      |> Map.put(:synonyms, updated_synonyms)

    Multi.update(multi, :update_target, SpeciesSchema.changeset(target, attrs))
  end

  defp transfer_sources(multi, source, target, include_source_ids) do
    target_source_ids = MapSet.new(target.species_sources, & &1.source_id)

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
        is_preferred: false
      }

      step_name = :"transfer_source_#{ss.source_id}"
      Multi.insert(acc, step_name, SpeciesSource.changeset(%SpeciesSource{}, attrs))
    end)
  end

  defp update_references(multi, source, target) do
    source_name = source.scientific_name
    target_name = target.scientific_name
    references = find_references(source_name)

    Enum.reduce(references, multi, fn ref, acc ->
      step_name = :"update_ref_#{ref.species.id}_#{ref.reference_type}"

      Multi.run(acc, step_name, fn repo, _changes ->
        species = repo.get!(SpeciesSchema, ref.species.id)
        attrs = build_reference_update(species, ref.reference_type, source_name, target_name)

        species
        |> SpeciesSchema.changeset(attrs)
        |> repo.update()
      end)
    end)
  end

  defp build_reference_update(_species, "parent1", _source_name, target_name) do
    %{parent1: target_name}
  end

  defp build_reference_update(_species, "parent2", _source_name, target_name) do
    %{parent2: target_name}
  end

  defp build_reference_update(species, "hybrids", source_name, target_name) do
    updated =
      species.hybrids
      |> Species.parse_json_array()
      |> Enum.map(fn h ->
        if String.downcase(h) == String.downcase(source_name), do: target_name, else: h
      end)
      |> remove_self_references(species.scientific_name)
      |> Enum.uniq_by(&String.downcase/1)
      |> Jason.encode!()

    %{hybrids: updated}
  end

  defp build_reference_update(species, "closely_related_to", source_name, target_name) do
    updated =
      species.closely_related_to
      |> Species.parse_json_array()
      |> Enum.map(fn r ->
        if String.downcase(r) == String.downcase(source_name), do: target_name, else: r
      end)
      |> remove_self_references(species.scientific_name)
      |> Enum.uniq_by(&String.downcase/1)
      |> Jason.encode!()

    %{closely_related_to: updated}
  end

  defp remove_self_references(names, species_name) do
    lower_self = String.downcase(species_name)
    Enum.reject(names, &(String.downcase(&1) == lower_self))
  end

  defp delete_source(multi, source) do
    Multi.delete(multi, :delete_source, source)
  end

  defp handle_transaction_result({:ok, _changes}, target_name) do
    target = Species.get_species_full(target_name)
    {:ok, target}
  end

  defp handle_transaction_result({:error, step, changeset, _changes}, _target_name) do
    {:error, step, changeset}
  end
end
