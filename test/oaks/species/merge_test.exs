defmodule Oaks.Species.MergeTest do
  @moduledoc """
  Tests for the Species.Merge context module.
  """
  use Oaks.DataCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Species
  alias Oaks.Species.Merge

  # A small world: ×bebbiana has parents alba × macrocarpa; alba lists
  # ×bebbiana as a hybrid and stellata as closely related. alba has two
  # sources, rubra one, and stellata one that alba lacks (`compendium`).
  # Names carry a unique suffix so they can't clash with seeded rows.
  setup do
    n = System.unique_integer([:positive])
    names = %{alba: "alba#{n}", stellata: "stellata#{n}", bebbiana: "×bebbiana#{n}"}

    inat = source_fixture()
    ootw = source_fixture()
    compendium = source_fixture()

    stellata =
      species_fixture(
        scientific_name: names.stellata,
        author: "Wangenh. 1787",
        subgenus: "Quercus",
        section: "Quercus",
        subsection: "Stellatae"
      )

    bebbiana =
      hybrid_fixture(scientific_name: names.bebbiana, parent1: names.alba, parent2: "macrocarpa")

    alba =
      species_fixture(
        scientific_name: names.alba,
        author: "L. 1753",
        subgenus: "Quercus",
        section: "Quercus",
        hybrids: [names.bebbiana],
        closely_related_to: [names.stellata],
        synonyms: ["alba var. repanda"]
      )

    rubra = species_fixture(scientific_name: "rubra#{n}", author: "L. 1753")
    velutina = species_fixture(scientific_name: "velutina#{n}", author: "Lam. 1785")

    species_source_fixture(alba, ootw, is_preferred: true)
    species_source_fixture(alba, inat)
    species_source_fixture(rubra, ootw, is_preferred: true)
    species_source_fixture(stellata, compendium, is_preferred: true)

    %{
      alba: alba.scientific_name,
      stellata: stellata.scientific_name,
      bebbiana: bebbiana.scientific_name,
      rubra: rubra.scientific_name,
      velutina: velutina.scientific_name,
      compendium: compendium
    }
  end

  describe "preview_merge/2" do
    test "returns preview with field comparisons", ctx do
      assert {:ok, preview} = Merge.preview_merge(ctx.stellata, ctx.alba)

      assert preview.source.scientific_name == ctx.stellata
      assert preview.target.scientific_name == ctx.alba

      assert is_list(preview.field_comparisons)
      assert preview.field_comparisons != []

      # author differs between stellata and alba
      author_cmp = Enum.find(preview.field_comparisons, &(&1.field == :author))
      assert author_cmp.source_value == "Wangenh. 1787"
      assert author_cmp.target_value == "L. 1753"
      assert author_cmp.differs
    end

    test "identifies synonym-only sources", ctx do
      assert {:ok, preview} = Merge.preview_merge(ctx.stellata, ctx.alba)

      synonym_source_ids =
        Enum.map(preview.synonym_only_sources, & &1.source_id)

      assert ctx.compendium.id in synonym_source_ids
    end

    test "computes synonyms to add", ctx do
      assert {:ok, preview} = Merge.preview_merge(ctx.stellata, ctx.alba)

      assert ctx.stellata in preview.synonyms_to_add
    end

    test "detects subsection difference", ctx do
      assert {:ok, preview} = Merge.preview_merge(ctx.stellata, ctx.alba)

      subsection_cmp = Enum.find(preview.field_comparisons, &(&1.field == :subsection))
      assert subsection_cmp.source_value == "Stellatae"
      assert subsection_cmp.target_value == nil
      assert subsection_cmp.differs
    end

    test "returns error for same species", ctx do
      assert {:error, :same_species} = Merge.preview_merge(ctx.alba, ctx.alba)
    end

    test "returns error for same species (case-insensitive)", ctx do
      assert {:error, :same_species} = Merge.preview_merge(String.capitalize(ctx.alba), ctx.alba)
    end

    test "returns error for nonexistent source species", ctx do
      assert {:error, :source_not_found} = Merge.preview_merge("nonexistent", ctx.alba)
    end

    test "returns error for nonexistent target species", ctx do
      assert {:error, :target_not_found} = Merge.preview_merge(ctx.alba, "nonexistent")
    end
  end

  describe "execute_merge/3" do
    test "adds synonym to target", ctx do
      assert {:ok, target} = Merge.execute_merge(ctx.stellata, ctx.alba)

      synonyms = Species.parse_json_array(target.synonyms)
      assert ctx.stellata in synonyms
      # Original synonym should still be there
      assert "alba var. repanda" in synonyms
    end

    test "deletes source species after merge", ctx do
      assert {:ok, _target} = Merge.execute_merge(ctx.velutina, ctx.rubra)

      assert Species.get_species_by_name(ctx.velutina) == nil
    end

    test "transfers sources from synonym to target", ctx do
      merge_opts = %{"include_sources" => [ctx.compendium.id]}
      assert {:ok, target} = Merge.execute_merge(ctx.stellata, ctx.alba, merge_opts)

      source_ids = Enum.map(target.species_sources, & &1.source_id)
      assert ctx.compendium.id in source_ids
    end

    test "does not transfer unchecked sources", ctx do
      merge_opts = %{"include_sources" => []}
      assert {:ok, target} = Merge.execute_merge(ctx.stellata, ctx.alba, merge_opts)

      source_ids = Enum.map(target.species_sources, & &1.source_id)
      refute ctx.compendium.id in source_ids
    end

    test "applies edited field values", ctx do
      merge_opts = %{
        "edited_fields" => %{"author" => "Updated Author"},
        "include_sources" => []
      }

      assert {:ok, target} = Merge.execute_merge(ctx.velutina, ctx.rubra, merge_opts)
      assert target.author == "Updated Author"
    end

    test "updates references in other species", ctx do
      # ×bebbiana has parent1 = alba, so merging alba into rubra repoints it
      merge_opts = %{"include_sources" => []}
      assert {:ok, _target} = Merge.execute_merge(ctx.alba, ctx.rubra, merge_opts)

      bebbiana = Species.get_species_by_name(ctx.bebbiana)
      assert bebbiana.parent1 == ctx.rubra
    end

    test "returns error for nonexistent species", ctx do
      assert {:error, :load, _} = Merge.execute_merge("nonexistent", ctx.alba)
    end
  end

  describe "find_references/1" do
    test "finds parent references", ctx do
      refs = Merge.find_references(ctx.alba)
      parent_refs = Enum.filter(refs, &(&1.reference_type == "parent1"))
      species_names = Enum.map(parent_refs, & &1.species.scientific_name)
      assert ctx.bebbiana in species_names
    end

    test "finds closely_related_to references", ctx do
      refs = Merge.find_references(ctx.stellata)
      related_refs = Enum.filter(refs, &(&1.reference_type == "closely_related_to"))
      species_names = Enum.map(related_refs, & &1.species.scientific_name)
      assert ctx.alba in species_names
    end

    test "returns empty list for unreferenced species", ctx do
      refs = Merge.find_references(ctx.velutina)
      assert refs == []
    end
  end

  describe "detect_self_references/2" do
    test "flags a target parent that points at the synonym", ctx do
      target = %{Species.get_species_full(ctx.alba) | parent1: ctx.stellata}
      stellata = ctx.stellata

      assert [%{field: "parent1", value: ^stellata}] =
               Merge.detect_self_references(target, ctx.stellata)
    end

    test "list mentions of the synonym are not issues; the merge removes them", ctx do
      # alba lists stellata as closely related
      target = Species.get_species_full(ctx.alba)
      assert Merge.detect_self_references(target, ctx.stellata) == []
    end

    test "returns empty when no self-references", ctx do
      target = Species.get_species_full(ctx.rubra)
      issues = Merge.detect_self_references(target, ctx.velutina)
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

    test "points escaped-× hybrid list entries at the target", ctx do
      "×" <> epithet = ctx.bebbiana
      set!(ctx.velutina, hybrids: ~s(["\\u00d7#{epithet}"]))

      {:ok, _} = Merge.execute_merge(ctx.bebbiana, ctx.rubra)

      assert Species.get_species_by_name(ctx.velutina).hybrids == Jason.encode!([ctx.rubra])
    end

    test "clears a target parent that named the synonym instead of making it its own parent",
         ctx do
      set!(ctx.rubra, parent1: ctx.stellata)

      {:ok, _} = Merge.execute_merge(ctx.stellata, ctx.rubra, %{"edited_fields" => %{}})

      assert Species.get_species_by_name(ctx.rubra).parent1 == nil
    end

    test "adds the synonym's name lists to the target and drops self mentions", ctx do
      set!(ctx.stellata,
        hybrids: Jason.encode!([ctx.bebbiana]),
        closely_related_to: Jason.encode!([ctx.alba, ctx.velutina])
      )

      {:ok, _} = Merge.execute_merge(ctx.stellata, ctx.alba)

      alba = Species.get_species_by_name(ctx.alba)
      assert Species.parse_name_list(alba.hybrids) == [ctx.bebbiana]
      assert Species.parse_name_list(alba.closely_related_to) == [ctx.velutina]
    end

    test "keeps the preferred flag on a moved source when the target has none", ctx do
      stellata = Species.get_species_full(ctx.stellata)
      [ss] = stellata.species_sources
      ss |> Ecto.Changeset.change(is_preferred: true) |> Oaks.Repo.update!()

      {:ok, target} =
        Merge.execute_merge(ctx.stellata, ctx.velutina, %{"include_sources" => [ss.source_id]})

      assert [%{is_preferred: true}] = target.species_sources
    end

    test "refuses to merge a species into itself", ctx do
      assert {:error, :load, _} = Merge.execute_merge(ctx.alba, ctx.alba)
      assert Species.get_species_by_name(ctx.alba)
    end
  end
end
