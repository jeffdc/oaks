defmodule Oaks.SearchTest do
  @moduledoc """
  Tests for the unified search context.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use Oaks.DataCase

  alias Oaks.Search

  describe "search/2" do
    test "returns matching species by scientific name" do
      %{species: species} = Search.search("alba")
      assert Enum.any?(species, &(&1.scientific_name == "alba"))
    end

    test "returns matching species by author" do
      %{species: species} = Search.search("L. 1753")
      names = Enum.map(species, & &1.scientific_name)
      assert "alba" in names
      assert "rubra" in names
    end

    test "returns matching species by common name (local_names)" do
      %{species: species} = Search.search("white oak")
      assert Enum.any?(species, &(&1.scientific_name == "alba"))
    end

    test "returns matching taxa by name" do
      %{taxa: taxa} = Search.search("lobatae")
      names = Enum.map(taxa, & &1.name)
      assert "Lobatae" in names
    end

    test "returns matching sources by name" do
      %{sources: sources} = Search.search("iNaturalist")
      assert Enum.any?(sources, &(&1.name == "iNaturalist"))
    end

    test "search is case-insensitive" do
      %{species: upper} = Search.search("ALBA")
      %{species: lower} = Search.search("alba")
      %{species: mixed} = Search.search("AlBa")

      assert length(upper) == length(lower)
      assert length(lower) == length(mixed)
      assert Enum.any?(lower, &(&1.scientific_name == "alba"))
    end

    test "returns empty lists for no matches" do
      result = Search.search("zzzznonexistent")
      assert result.species == []
      assert result.taxa == []
      assert result.sources == []
      assert result.counts.total == 0
    end

    test "includes counts for each type" do
      result = Search.search("alba")
      assert is_integer(result.counts.species)
      assert is_integer(result.counts.taxa)
      assert is_integer(result.counts.sources)

      assert result.counts.total ==
               result.counts.species + result.counts.taxa + result.counts.sources
    end

    test "taxa results include species_count" do
      %{taxa: taxa} = Search.search("Quercus")
      quercus_subgenus = Enum.find(taxa, &(&1.level == "subgenus" && &1.name == "Quercus"))
      assert quercus_subgenus
      assert quercus_subgenus.species_count > 0
    end

    test "taxa results include ancestry path" do
      %{taxa: taxa} = Search.search("Stellatae")
      stellatae = Enum.find(taxa, &(&1.name == "Stellatae"))
      assert stellatae
      assert is_list(stellatae.path)
      assert "Stellatae" in stellatae.path
    end

    test "respects limit parameter" do
      result = Search.search("a", 2)
      assert length(result.species) <= 2
      assert length(result.taxa) <= 2
      assert length(result.sources) <= 2
    end

    test "does not return duplicate species from joined search" do
      # "alba" matches species name AND local_names ("white oak" contains no "alba",
      # but "alba" matches the scientific_name). The join shouldn't create duplicates.
      %{species: species} = Search.search("alba")
      ids = Enum.map(species, & &1.id)
      assert ids == Enum.uniq(ids)
    end
  end
end
