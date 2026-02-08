defmodule Oaks.SpeciesTest do
  @moduledoc """
  Tests for the Species context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use Oaks.DataCase

  alias Oaks.Species

  describe "list_all_species/1" do
    test "returns all species ordered by name" do
      species = Species.list_all_species()
      names = Enum.map(species, & &1.scientific_name)
      assert length(names) == 5
      assert names == Enum.sort(names)
    end

    test "filters by subgenus" do
      species = Species.list_all_species(%{"subgenus" => "Lobatae"})
      assert length(species) == 2
      assert Enum.all?(species, &(&1.subgenus == "Lobatae"))
    end

    test "filters by section" do
      species = Species.list_all_species(%{"section" => "Quercus"})
      assert length(species) == 3
      assert Enum.all?(species, &(&1.section == "Quercus"))
    end

    test "filters by search term" do
      species = Species.list_all_species(%{"search" => "alb"})
      assert length(species) == 1
      assert hd(species).scientific_name == "alba"
    end

    test "search is case-insensitive" do
      species = Species.list_all_species(%{"search" => "RUBRA"})
      assert length(species) == 1
      assert hd(species).scientific_name == "rubra"
    end

    test "combines search and taxonomy filters" do
      species = Species.list_all_species(%{"search" => "a", "subgenus" => "Quercus"})
      names = Enum.map(species, & &1.scientific_name)
      assert "alba" in names
      assert "stellata" in names
      refute "rubra" in names
    end

    test "returns empty list when no matches" do
      species = Species.list_all_species(%{"search" => "zzzznonexistent"})
      assert species == []
    end
  end

  describe "distinct_subgenera/0" do
    test "returns unique subgenus values sorted" do
      subgenera = Species.distinct_subgenera()
      assert subgenera == ["Lobatae", "Quercus"]
    end
  end

  describe "distinct_sections/0" do
    test "returns unique section values sorted" do
      sections = Species.distinct_sections()
      assert sections == ["Lobatae", "Quercus"]
    end
  end

  describe "get_species_by_name/1" do
    test "returns species when found" do
      species = Species.get_species_by_name("alba")
      assert species.scientific_name == "alba"
      assert species.author == "L. 1753"
    end

    test "returns nil when not found" do
      assert Species.get_species_by_name("nonexistent") == nil
    end
  end

  describe "get_species_full/1" do
    test "returns species with preloaded sources" do
      species = Species.get_species_full("alba")
      assert species.scientific_name == "alba"
      assert length(species.species_sources) == 2

      preferred = Enum.find(species.species_sources, & &1.is_preferred)
      assert preferred.source.name == "Oaks of the World"
    end

    test "preferred source comes first" do
      species = Species.get_species_full("alba")
      [first | _] = species.species_sources
      assert first.is_preferred == true
    end

    test "returns nil when species not found" do
      assert Species.get_species_full("nonexistent") == nil
    end
  end

  describe "create_species/1" do
    test "creates species with valid attrs" do
      attrs = %{scientific_name: "coccinea", is_hybrid: false, author: "Muenchh."}
      assert {:ok, species} = Species.create_species(attrs)
      assert species.scientific_name == "coccinea"
      assert species.author == "Muenchh."
      refute species.is_hybrid
    end

    test "fails with duplicate scientific_name" do
      attrs = %{scientific_name: "alba", is_hybrid: false}
      assert {:error, changeset} = Species.create_species(attrs)
      assert %{scientific_name: ["has already been taken"]} = errors_on(changeset)
    end

    test "fails without required fields" do
      assert {:error, changeset} = Species.create_species(%{})
      errors = errors_on(changeset)
      assert errors[:scientific_name]
    end

    test "validates conservation_status values" do
      attrs = %{scientific_name: "test_sp", is_hybrid: false, conservation_status: "INVALID"}
      assert {:error, changeset} = Species.create_species(attrs)
      assert %{conservation_status: [_]} = errors_on(changeset)
    end

    test "accepts valid conservation_status" do
      attrs = %{scientific_name: "test_sp", is_hybrid: false, conservation_status: "VU"}
      assert {:ok, species} = Species.create_species(attrs)
      assert species.conservation_status == "VU"
    end
  end

  describe "update_species/2" do
    test "updates species with valid attrs" do
      species = Species.get_species_by_name("alba")
      assert {:ok, updated} = Species.update_species(species, %{author: "Linnaeus"})
      assert updated.author == "Linnaeus"
      assert updated.scientific_name == "alba"
    end

    test "fails with invalid attrs" do
      species = Species.get_species_by_name("alba")
      assert {:error, changeset} = Species.update_species(species, %{scientific_name: ""})
      assert %{scientific_name: [_]} = errors_on(changeset)
    end
  end

  describe "delete_species/1" do
    test "deletes species" do
      species = Species.get_species_by_name("velutina")
      assert {:ok, _} = Species.delete_species(species)
      assert Species.get_species_by_name("velutina") == nil
    end

    test "cascades to species_sources" do
      species = Species.get_species_by_name("alba")
      full = Species.get_species_full("alba")
      assert full.species_sources != []

      assert {:ok, _} = Species.delete_species(species)
      assert Species.get_species_by_name("alba") == nil
    end
  end

  describe "change_species/2" do
    test "returns a changeset" do
      species = Species.get_species_by_name("alba")
      changeset = Species.change_species(species)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "find_synonym/1" do
    test "finds species with matching synonym" do
      species = Species.find_synonym("alba var. repanda")
      assert species.scientific_name == "alba"
    end

    test "returns nil when no synonym match" do
      assert Species.find_synonym("nonexistent synonym") == nil
    end
  end
end
