defmodule OakCompendium.Species.MergeTest do
  @moduledoc """
  Tests for the Species.Merge context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendium.DataCase

  alias OakCompendium.Species
  alias OakCompendium.Species.Merge

  describe "preview_merge/2" do
    test "returns preview with field comparisons" do
      assert {:ok, preview} = Merge.preview_merge("stellata", "alba")

      assert preview.source.scientific_name == "stellata"
      assert preview.target.scientific_name == "alba"

      assert is_list(preview.field_comparisons)
      assert preview.field_comparisons != []

      # author differs between stellata and alba
      author_cmp = Enum.find(preview.field_comparisons, &(&1.field == :author))
      assert author_cmp.source_value == "Wangenh. 1787"
      assert author_cmp.target_value == "L. 1753"
      assert author_cmp.differs
    end

    test "identifies synonym-only sources" do
      # stellata has source 3 (Oak Compendium), alba does not
      assert {:ok, preview} = Merge.preview_merge("stellata", "alba")

      synonym_source_ids =
        Enum.map(preview.synonym_only_sources, & &1.source_id)

      assert 3 in synonym_source_ids
    end

    test "computes synonyms to add" do
      assert {:ok, preview} = Merge.preview_merge("stellata", "alba")

      assert "stellata" in preview.synonyms_to_add
    end

    test "detects subsection difference" do
      assert {:ok, preview} = Merge.preview_merge("stellata", "alba")

      subsection_cmp = Enum.find(preview.field_comparisons, &(&1.field == :subsection))
      assert subsection_cmp.source_value == "Stellatae"
      assert subsection_cmp.target_value == nil
      assert subsection_cmp.differs
    end

    test "returns error for same species" do
      assert {:error, :same_species} = Merge.preview_merge("alba", "alba")
    end

    test "returns error for same species (case-insensitive)" do
      assert {:error, :same_species} = Merge.preview_merge("Alba", "alba")
    end

    test "returns error for nonexistent source species" do
      assert {:error, :source_not_found} = Merge.preview_merge("nonexistent", "alba")
    end

    test "returns error for nonexistent target species" do
      assert {:error, :source_not_found} = Merge.preview_merge("alba", "nonexistent")
    end
  end

  describe "execute_merge/3" do
    test "adds synonym to target" do
      assert {:ok, target} = Merge.execute_merge("stellata", "alba")

      synonyms = Species.parse_json_array(target.synonyms)
      assert "stellata" in synonyms
      # Original synonym should still be there
      assert "alba var. repanda" in synonyms
    end

    test "deletes source species after merge" do
      assert {:ok, _target} = Merge.execute_merge("velutina", "rubra")

      assert Species.get_species_by_name("velutina") == nil
    end

    test "transfers sources from synonym to target" do
      # stellata has source 3 (Oak Compendium), alba does not
      merge_opts = %{"include_sources" => [3]}
      assert {:ok, target} = Merge.execute_merge("stellata", "alba", merge_opts)

      source_ids = Enum.map(target.species_sources, & &1.source_id)
      assert 3 in source_ids
    end

    test "does not transfer unchecked sources" do
      # Don't include source 3
      merge_opts = %{"include_sources" => []}
      assert {:ok, target} = Merge.execute_merge("stellata", "alba", merge_opts)

      source_ids = Enum.map(target.species_sources, & &1.source_id)
      refute 3 in source_ids
    end

    test "applies edited field values" do
      merge_opts = %{
        "edited_fields" => %{"author" => "Updated Author"},
        "include_sources" => []
      }

      assert {:ok, target} = Merge.execute_merge("velutina", "rubra", merge_opts)
      assert target.author == "Updated Author"
    end

    test "updates references in other species" do
      # ×bebbiana has parent1 = "alba"
      # If we merge alba into rubra, ×bebbiana.parent1 should become "rubra"
      merge_opts = %{"include_sources" => []}
      assert {:ok, _target} = Merge.execute_merge("alba", "rubra", merge_opts)

      bebbiana = Species.get_species_by_name("×bebbiana")
      assert bebbiana.parent1 == "rubra"
    end

    test "returns error for nonexistent species" do
      assert {:error, :load, _} = Merge.execute_merge("nonexistent", "alba")
    end
  end

  describe "find_references/1" do
    test "finds parent references" do
      refs = Merge.find_references("alba")
      parent_refs = Enum.filter(refs, &(&1.reference_type == "parent1"))
      species_names = Enum.map(parent_refs, & &1.species.scientific_name)
      assert "×bebbiana" in species_names
    end

    test "finds closely_related_to references" do
      refs = Merge.find_references("stellata")
      related_refs = Enum.filter(refs, &(&1.reference_type == "closely_related_to"))
      species_names = Enum.map(related_refs, & &1.species.scientific_name)
      assert "alba" in species_names
    end

    test "returns empty list for unreferenced species" do
      refs = Merge.find_references("velutina")
      assert refs == []
    end
  end

  describe "detect_self_references/2" do
    test "detects when target would reference itself via closely_related_to" do
      # alba has closely_related_to = ["stellata"]
      # If stellata is merged into alba, alba would reference itself
      target = Species.get_species_full("alba")
      issues = Merge.detect_self_references(target, "stellata")

      assert issues != []
      assert Enum.any?(issues, &(&1.field == "closely_related_to"))
    end

    test "returns empty when no self-references" do
      target = Species.get_species_full("rubra")
      issues = Merge.detect_self_references(target, "velutina")
      assert issues == []
    end
  end
end
