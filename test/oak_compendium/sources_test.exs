defmodule OakCompendium.SourcesTest do
  @moduledoc """
  Tests for the Sources context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendium.DataCase

  alias OakCompendium.Sources

  describe "list_sources/0" do
    test "returns all sources ordered by name" do
      sources = Sources.list_sources()
      assert length(sources) == 3
      names = Enum.map(sources, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "list_sources_with_species_count/0" do
    test "returns all sources with species counts" do
      sources = Sources.list_sources_with_species_count()
      assert length(sources) == 3

      oaks_of_world = Enum.find(sources, &(&1.name == "Oaks of the World"))
      assert oaks_of_world.species_count == 2

      inat = Enum.find(sources, &(&1.name == "iNaturalist"))
      assert inat.species_count == 1

      oak_comp = Enum.find(sources, &(&1.name == "Oak Compendium"))
      assert oak_comp.species_count == 0
    end

    test "returns expected fields" do
      [source | _] = Sources.list_sources_with_species_count()
      assert Map.has_key?(source, :id)
      assert Map.has_key?(source, :name)
      assert Map.has_key?(source, :source_type)
      assert Map.has_key?(source, :species_count)
    end

    test "sources are ordered by name" do
      sources = Sources.list_sources_with_species_count()
      names = Enum.map(sources, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_source/1" do
    test "returns the source for a valid ID" do
      source = Sources.get_source(2)
      assert source.name == "Oaks of the World"
      assert source.source_type == "website"
    end

    test "returns nil for unknown ID" do
      assert Sources.get_source(999) == nil
    end
  end

  describe "get_species_for_source/1" do
    test "returns species associated with a source" do
      species = Sources.get_species_for_source(2)
      assert length(species) == 2
      names = Enum.map(species, & &1.scientific_name)
      assert "alba" in names
      assert "rubra" in names
    end

    test "returns species ordered by scientific name" do
      species = Sources.get_species_for_source(2)
      names = Enum.map(species, & &1.scientific_name)
      assert names == Enum.sort(names)
    end

    test "returns empty list for source with no species" do
      assert Sources.get_species_for_source(3) == []
    end

    test "returns empty list for nonexistent source" do
      assert Sources.get_species_for_source(999) == []
    end
  end

  describe "count/0" do
    test "returns total number of sources" do
      assert Sources.count() == 3
    end
  end
end
