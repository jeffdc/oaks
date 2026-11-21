defmodule Oaks.Species.ReferencesTest do
  @moduledoc """
  Tests for name references between species, and for rename and delete,
  which keep them in sync. Each test builds a small world: ×bebbiana has
  parents alba × macrocarpa, and alba lists ×bebbiana as a hybrid and
  stellata as closely related. Names carry a unique suffix.
  """
  use Oaks.DataCase

  import Oaks.SpeciesFixtures

  alias Oaks.Species
  alias Oaks.Species.References

  doctest Oaks.Species.References

  setup do
    n = System.unique_integer([:positive])
    alba = "alba#{n}"
    stellata = species_fixture(scientific_name: "stellata#{n}")

    bebbiana =
      hybrid_fixture(scientific_name: "×bebbiana#{n}", parent1: alba, parent2: "macrocarpa")

    species_fixture(
      scientific_name: alba,
      hybrids: [bebbiana.scientific_name],
      closely_related_to: [stellata.scientific_name]
    )

    %{
      n: n,
      alba: alba,
      stellata: stellata.scientific_name,
      bebbiana: bebbiana.scientific_name,
      rubra: species_fixture(scientific_name: "rubra#{n}").scientific_name,
      velutina: species_fixture(scientific_name: "velutina#{n}").scientific_name
    }
  end

  defp set!(name, changes) do
    name
    |> Species.get_species_by_name()
    |> Ecto.Changeset.change(changes)
    |> Oaks.Repo.update!()
  end

  describe "find/1" do
    test "finds parent and list mentions, ignoring × spacing and escapes", ctx do
      "×" <> epithet = ctx.bebbiana
      set!(ctx.velutina, hybrids: ~s(["\\u00d7 #{epithet}"]))

      refs = References.find(ctx.bebbiana)
      %{alba: alba, velutina: velutina} = ctx

      assert [
               %{species: %{scientific_name: ^alba}, fields: [:hybrids]},
               %{species: %{scientific_name: ^velutina}, fields: [:hybrids]}
             ] = refs
    end

    test "finds parents", %{alba: alba, bebbiana: bebbiana} do
      assert [%{species: %{scientific_name: ^bebbiana}, fields: [:parent1]}] =
               References.find(alba)
    end
  end

  describe "renaming a species" do
    test "points every mention at the new name and keeps the old name as a synonym", ctx do
      new_name = "alba-renamed#{ctx.n}"

      {:ok, renamed} =
        Species.update_species(Species.get_species_by_name(ctx.alba), %{
          "scientific_name" => new_name
        })

      assert Species.get_species_by_name(ctx.bebbiana).parent1 == new_name
      assert ctx.alba in Species.parse_name_list(renamed.synonyms)
      assert Species.find_synonym(ctx.alba).scientific_name == new_name
    end

    test "renaming a hybrid updates parents' hybrid lists", ctx do
      new_name = "× bebbiana-x#{ctx.n}"
      bebbiana = Species.get_species_by_name(ctx.bebbiana)

      {:ok, _} = Species.update_species(bebbiana, %{"scientific_name" => new_name})

      assert Species.parse_name_list(Species.get_species_by_name(ctx.alba).hybrids) == [new_name]
    end

    test "a failed rename changes nothing", ctx do
      alba = Species.get_species_by_name(ctx.alba)

      assert {:error, changeset} =
               Species.update_species(alba, %{"scientific_name" => ctx.rubra})

      assert changeset.errors[:scientific_name]
      assert Species.get_species_by_name(ctx.bebbiana).parent1 == ctx.alba
    end

    test "edits that keep the name don't touch references", ctx do
      alba = Species.get_species_by_name(ctx.alba)
      {:ok, updated} = Species.update_species(alba, %{"author" => "L."})

      assert updated.synonyms == alba.synonyms
    end
  end

  describe "deleting a species" do
    test "removes its name from every species that mentions it", ctx do
      {:ok, _} = Species.delete_species(Species.get_species_by_name(ctx.stellata))

      assert Species.get_species_by_name(ctx.alba).closely_related_to == nil
    end

    test "clears parents that named it", ctx do
      {:ok, _} = Species.delete_species(Species.get_species_by_name(ctx.alba))

      assert Species.get_species_by_name(ctx.bebbiana).parent1 == nil
    end
  end
end
