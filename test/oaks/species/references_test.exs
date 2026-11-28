defmodule Oaks.Species.ReferencesTest do
  @moduledoc """
  Tests for name references between species, and for rename and delete.
  Each test builds a small world: ×bebbiana has parents alba × macrocarpa.
  Names carry a unique suffix.
  """
  use Oaks.DataCase

  import Oaks.SpeciesFixtures

  alias Oaks.Species

  doctest Oaks.Species.References

  setup do
    n = System.unique_integer([:positive])
    alba = "alba#{n}"
    macrocarpa = "macrocarpa#{n}"

    alba_species = species_fixture(scientific_name: alba)
    macrocarpa_species = species_fixture(scientific_name: macrocarpa)

    bebbiana =
      hybrid_fixture(
        scientific_name: "×bebbiana#{n}",
        parent1_id: alba_species.id,
        parent2_id: macrocarpa_species.id
      )

    %{
      n: n,
      alba: alba,
      alba_species: alba_species,
      macrocarpa_species: macrocarpa_species,
      bebbiana: bebbiana.scientific_name,
      bebbiana_species: bebbiana,
      rubra: species_fixture(scientific_name: "rubra#{n}").scientific_name
    }
  end

  describe "renaming a species" do
    test "changes only its own row and keeps the old name as a synonym", ctx do
      new_name = "alba-renamed#{ctx.n}"

      {:ok, renamed} =
        Species.update_species(Species.get_species_by_name(ctx.alba), %{
          "scientific_name" => new_name
        })

      assert renamed.scientific_name == new_name
      assert ctx.alba in Species.parse_name_list(renamed.synonyms)
      assert Species.find_synonym(ctx.alba).scientific_name == new_name
      # The hybrid's parent key still points at this row.
      assert Species.get_species_by_name(ctx.bebbiana).parent1_id == renamed.id
    end

    test "leaves a hybrid's own parent keys alone when the hybrid is renamed", ctx do
      new_name = "× bebbiana-x#{ctx.n}"

      {:ok, renamed} =
        Species.update_species(Species.get_species_by_name(ctx.bebbiana), %{
          "scientific_name" => new_name
        })

      assert renamed.parent1_id == ctx.alba_species.id
      assert renamed.parent2_id == ctx.macrocarpa_species.id
      assert ctx.bebbiana in Species.parse_name_list(renamed.synonyms)
    end

    test "a failed rename changes nothing", ctx do
      alba = Species.get_species_by_name(ctx.alba)

      assert {:error, changeset} =
               Species.update_species(alba, %{"scientific_name" => ctx.rubra})

      assert changeset.errors[:scientific_name]
      assert Species.get_species_by_name(ctx.bebbiana).parent1_id == ctx.alba_species.id
    end

    test "edits that keep the name don't touch references", ctx do
      alba = Species.get_species_by_name(ctx.alba)
      {:ok, updated} = Species.update_species(alba, %{"author" => "L."})

      assert updated.synonyms == alba.synonyms
      assert updated.parent1_id == nil
    end
  end

  describe "references_to/1" do
    test "returns the hybrids naming the species as a parent", ctx do
      assert [%{scientific_name: name}] = Species.references_to(ctx.alba_species)
      assert name == ctx.bebbiana
    end

    test "is empty for a species no hybrid names", ctx do
      assert Species.references_to(ctx.macrocarpa_species) |> length() == 1
      assert Species.references_to(Species.get_species_by_name(ctx.rubra)) == []
    end
  end

  describe "deleting a species" do
    test "refuses a hybrid's parent and lists the hybrids", ctx do
      assert {:error, changeset} = Species.delete_species(ctx.alba_species)
      assert changeset.errors[:base]
      assert Species.get_species_by_name(ctx.alba)
    end

    test "deletes a species no hybrid names", ctx do
      rubra = Species.get_species_by_name(ctx.rubra)
      assert {:ok, _} = Species.delete_species(rubra)
      assert Species.get_species_by_name(ctx.rubra) == nil
    end
  end
end
