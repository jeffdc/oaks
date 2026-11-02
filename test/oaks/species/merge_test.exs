defmodule Oaks.Species.MergeTest do
  @moduledoc """
  Tests for the Species.Merge context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use Oaks.DataCase

  alias Oaks.Species
  alias Oaks.Species.Merge

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
      assert {:error, :target_not_found} = Merge.preview_merge("alba", "nonexistent")
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
    test "flags a target parent that points at the synonym" do
      target = %{Species.get_species_full("alba") | parent1: "stellata"}

      assert [%{field: "parent1", value: "stellata"}] =
               Merge.detect_self_references(target, "stellata")
    end

    test "list mentions of the synonym are not issues; the merge removes them" do
      # alba has closely_related_to = ["stellata"]
      target = Species.get_species_full("alba")
      assert Merge.detect_self_references(target, "stellata") == []
    end

    test "returns empty when no self-references" do
      target = Species.get_species_full("rubra")
      issues = Merge.detect_self_references(target, "velutina")
      assert issues == []
    end
  end

  describe "execute_merge/3 relationships" do
    defp set!(name, changes) do
      name
      |> Species.get_species_by_name()
      |> Ecto.Changeset.change(changes)
      |> Oaks.Repo.update!()
    end

    test "points escaped-× hybrid list entries at the target" do
      set!("velutina", hybrids: ~s(["\\u00d7bebbiana"]))

      {:ok, _} = Merge.execute_merge("×bebbiana", "rubra")

      assert Species.get_species_by_name("velutina").hybrids == ~s(["rubra"])
    end

    test "clears a target parent that named the synonym instead of making it its own parent" do
      set!("rubra", parent1: "stellata")

      {:ok, _} = Merge.execute_merge("stellata", "rubra", %{"edited_fields" => %{}})

      assert Species.get_species_by_name("rubra").parent1 == nil
    end

    test "adds the synonym's name lists to the target and drops self mentions" do
      set!("stellata", hybrids: ~s(["×bebbiana"]), closely_related_to: ~s(["alba", "velutina"]))

      {:ok, _} = Merge.execute_merge("stellata", "alba")

      alba = Species.get_species_by_name("alba")
      assert Species.parse_name_list(alba.hybrids) == ["×bebbiana"]
      assert Species.parse_name_list(alba.closely_related_to) == ["velutina"]
    end

    test "keeps the preferred flag on a moved source when the target has none" do
      stellata = Species.get_species_full("stellata")
      [ss] = stellata.species_sources
      ss |> Ecto.Changeset.change(is_preferred: true) |> Oaks.Repo.update!()

      {:ok, target} =
        Merge.execute_merge("stellata", "velutina", %{"include_sources" => [ss.source_id]})

      assert [%{is_preferred: true}] = target.species_sources
    end

    test "refuses to merge a species into itself" do
      assert {:error, :load, _} = Merge.execute_merge("alba", "alba")
      assert Species.get_species_by_name("alba")
    end
  end
end
