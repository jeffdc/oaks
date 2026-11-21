defmodule Oaks.SourcesTest do
  @moduledoc """
  Tests for the Sources context module.
  """
  use Oaks.DataCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Sources

  # Two sources: `ootw` has alba and rubra, `compendium` has stellata.
  setup do
    n = System.unique_integer([:positive])
    alba = species_fixture(scientific_name: "alba#{n}")
    rubra = species_fixture(scientific_name: "rubra#{n}")
    stellata = species_fixture(scientific_name: "stellata#{n}")

    ootw = source_fixture(name: "Oaks of the World #{n}")
    compendium = source_fixture(name: "Oak Compendium #{n}", source_type: "personal_observation")

    species_source_fixture(rubra, ootw)
    species_source_fixture(alba, ootw)
    species_source_fixture(stellata, compendium)

    %{alba: alba, rubra: rubra, stellata: stellata, ootw: ootw, compendium: compendium}
  end

  describe "list_sources/0" do
    test "returns all sources ordered by name", %{ootw: ootw, compendium: compendium} do
      sources = Sources.list_sources()
      assert length(sources) == Sources.count()
      names = Enum.map(sources, & &1.name)
      assert names == Enum.sort(names)
      assert ootw.name in names
      assert compendium.name in names
    end
  end

  describe "list_sources_with_species_count/0" do
    test "returns all sources with species counts", %{ootw: ootw, compendium: compendium} do
      sources = Sources.list_sources_with_species_count()
      assert length(sources) == Sources.count()

      assert Enum.find(sources, &(&1.id == ootw.id)).species_count == 2
      assert Enum.find(sources, &(&1.id == compendium.id)).species_count == 1
    end

    test "counts zero for a source with no species" do
      unused = source_fixture()

      sources = Sources.list_sources_with_species_count()
      assert Enum.find(sources, &(&1.id == unused.id)).species_count == 0
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
    test "returns the source for a valid ID", %{ootw: ootw} do
      source = Sources.get_source(ootw.id)
      assert source.name == ootw.name
      assert source.source_type == "website"
    end

    test "returns nil for unknown ID" do
      assert Sources.get_source(-1) == nil
    end
  end

  describe "get_species_for_source/1" do
    test "returns species associated with a source", ctx do
      species = Sources.get_species_for_source(ctx.ootw.id)
      assert length(species) == 2
      names = Enum.map(species, & &1.scientific_name)
      assert ctx.alba.scientific_name in names
      assert ctx.rubra.scientific_name in names
    end

    test "returns species ordered by scientific name", %{ootw: ootw} do
      species = Sources.get_species_for_source(ootw.id)
      names = Enum.map(species, & &1.scientific_name)
      assert names == Enum.sort(names)
    end

    test "returns the one species of a single-species source", ctx do
      assert [species] = Sources.get_species_for_source(ctx.compendium.id)
      assert species.id == ctx.stellata.id
    end

    test "returns empty list for nonexistent source" do
      assert Sources.get_species_for_source(-1) == []
    end
  end

  describe "count/0" do
    test "returns total number of sources" do
      before = Sources.count()
      source_fixture()
      assert Sources.count() == before + 1
    end
  end

  describe "delete_source/1" do
    test "returns an error while species have data from the source", %{ootw: ootw} do
      assert {:error, changeset} = Sources.delete_source(ootw)
      assert changeset.errors[:id]
      assert Sources.get_source(ootw.id)
    end

    test "deletes a source with no species data" do
      {:ok, source} = Sources.create_source(%{name: "Unused", source_type: "website"})

      assert {:ok, _} = Sources.delete_source(source)
      refute Sources.get_source(source.id)
    end
  end
end
