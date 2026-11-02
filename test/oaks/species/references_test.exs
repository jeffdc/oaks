defmodule Oaks.Species.ReferencesTest do
  @moduledoc """
  Tests for name references between species, and for rename and delete,
  which keep them in sync. Uses seeded test data (see priv/repo/test_seeds.sql):
  ×bebbiana has parents alba × macrocarpa, and alba lists ["×bebbiana"] as
  hybrids and ["stellata"] as closely related.
  """
  use Oaks.DataCase

  alias Oaks.Species
  alias Oaks.Species.References

  doctest Oaks.Species.References

  defp set!(name, changes) do
    name
    |> Species.get_species_by_name()
    |> Ecto.Changeset.change(changes)
    |> Oaks.Repo.update!()
  end

  describe "find/1" do
    test "finds parent and list mentions, ignoring × spacing and escapes" do
      set!("velutina", hybrids: ~s(["\\u00d7 bebbiana"]))

      refs = References.find("×bebbiana")

      assert [
               %{species: %{scientific_name: "alba"}, fields: [:hybrids]},
               %{species: %{scientific_name: "velutina"}, fields: [:hybrids]}
             ] = refs
    end

    test "finds parents" do
      assert [%{species: %{scientific_name: "×bebbiana"}, fields: [:parent1]}] =
               References.find("alba")
    end
  end

  describe "renaming a species" do
    test "points every mention at the new name and keeps the old name as a synonym" do
      alba = Species.get_species_by_name("alba")

      {:ok, renamed} = Species.update_species(alba, %{"scientific_name" => "alba2"})

      assert Species.get_species_by_name("×bebbiana").parent1 == "alba2"
      assert "alba" in Species.parse_name_list(renamed.synonyms)
      assert Species.find_synonym("alba").scientific_name == "alba2"
    end

    test "renaming a hybrid updates parents' hybrid lists" do
      bebbiana = Species.get_species_by_name("×bebbiana")

      {:ok, _} = Species.update_species(bebbiana, %{"scientific_name" => "× bebbiana-x"})

      assert Species.parse_name_list(Species.get_species_by_name("alba").hybrids) == [
               "× bebbiana-x"
             ]
    end

    test "a failed rename changes nothing" do
      alba = Species.get_species_by_name("alba")

      assert {:error, changeset} = Species.update_species(alba, %{"scientific_name" => "rubra"})
      assert changeset.errors[:scientific_name]
      assert Species.get_species_by_name("×bebbiana").parent1 == "alba"
    end

    test "edits that keep the name don't touch references" do
      alba = Species.get_species_by_name("alba")
      {:ok, updated} = Species.update_species(alba, %{"author" => "L."})

      assert updated.synonyms == alba.synonyms
    end
  end

  describe "deleting a species" do
    test "removes its name from every species that mentions it" do
      {:ok, _} = Species.delete_species(Species.get_species_by_name("stellata"))

      assert Species.get_species_by_name("alba").closely_related_to == nil
    end

    test "clears parents that named it" do
      {:ok, _} = Species.delete_species(Species.get_species_by_name("alba"))

      assert Species.get_species_by_name("×bebbiana").parent1 == nil
    end
  end
end
