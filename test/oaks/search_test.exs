defmodule Oaks.SearchTest do
  @moduledoc """
  Tests for the unified search context.
  """
  use Oaks.DataCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Search

  setup do
    n = System.unique_integer([:positive])
    tree = taxon_tree_fixture()

    alba =
      species_fixture(
        scientific_name: "alba#{n}",
        author: "L. 1753 #{n}",
        taxon_id: tree.subgenus.id
      )

    rubra = species_fixture(scientific_name: "rubra#{n}", author: "L. 1753 #{n}")
    source = source_fixture(name: "iNaturalist #{n}")
    species_source_fixture(alba, source, local_names: ["white oak #{n}"])

    %{n: n, tree: tree, alba: alba, rubra: rubra, source: source}
  end

  describe "search/2" do
    test "returns matching species by scientific name", %{alba: alba} do
      assert alba.scientific_name in names(Search.search(alba.scientific_name))
    end

    test "returns matching species by author", %{n: n, alba: alba, rubra: rubra} do
      assert names(Search.search("L. 1753 #{n}")) == [alba.scientific_name, rubra.scientific_name]
    end

    test "returns matching species by common name (local_names)", %{n: n, alba: alba} do
      assert names(Search.search("white oak #{n}")) == [alba.scientific_name]
    end

    test "returns matching taxa by name", %{tree: tree} do
      %{taxa: taxa} = Search.search(String.downcase(tree.section.name))
      assert tree.section.name in Enum.map(taxa, & &1.name)
    end

    test "returns matching sources by name", %{source: source} do
      %{sources: sources} = Search.search(source.name)
      assert Enum.any?(sources, &(&1.name == source.name))
    end

    test "search is case-insensitive", %{alba: alba} do
      %{species: upper} = Search.search(String.upcase(alba.scientific_name))
      %{species: lower} = Search.search(alba.scientific_name)
      %{species: mixed} = Search.search(String.capitalize(alba.scientific_name))

      assert length(upper) == length(lower)
      assert length(lower) == length(mixed)
      assert Enum.any?(lower, &(&1.scientific_name == alba.scientific_name))
    end

    test "returns empty lists for no matches" do
      result = Search.search("zzzznonexistent")
      assert result.species == []
      assert result.taxa == []
      assert result.sources == []
      assert result.counts.total == 0
    end

    test "includes counts for each type", %{alba: alba} do
      result = Search.search(alba.scientific_name)
      assert is_integer(result.counts.species)
      assert is_integer(result.counts.taxa)
      assert is_integer(result.counts.sources)

      assert result.counts.total ==
               result.counts.species + result.counts.taxa + result.counts.sources
    end

    test "taxa results include species_count", %{tree: tree} do
      %{taxa: taxa} = Search.search(tree.subgenus.name)
      subgenus = Enum.find(taxa, &(&1.level == "subgenus" && &1.name == tree.subgenus.name))
      assert subgenus.species_count == 1
    end

    test "a taxon's count includes the species in its child taxa", %{tree: tree} do
      species_fixture(taxon_id: tree.section.id)

      %{taxa: taxa} = Search.search(tree.subgenus.name)
      subgenus = Enum.find(taxa, &(&1.level == "subgenus" && &1.name == tree.subgenus.name))
      assert subgenus.species_count == 2
    end

    test "taxa results include ancestry path", %{tree: tree} do
      %{taxa: taxa} = Search.search(tree.subsection.name)
      subsection = Enum.find(taxa, &(&1.name == tree.subsection.name))
      assert is_list(subsection.path)
      assert tree.subsection.name in subsection.path
    end

    test "respects limit parameter" do
      result = Search.search("a", 2)
      assert length(result.species) <= 2
      assert length(result.taxa) <= 2
      assert length(result.sources) <= 2
    end

    test "does not return duplicate species from joined search", %{n: n, alba: alba} do
      # alba matches by name and by author, and has a source whose local
      # names match too. The join shouldn't create duplicates.
      species_source_fixture(alba, source_fixture(), local_names: ["alba#{n} oak"])

      %{species: species} = Search.search(alba.scientific_name)
      ids = Enum.map(species, & &1.id)
      assert ids == Enum.uniq(ids)
    end

    test "matches LIKE wildcard characters literally" do
      wildcard = species_fixture(author: "Test_Author 100%")
      species_fixture(author: "L. 1753")

      assert names(Search.search("test_author")) == [wildcard.scientific_name]
      assert names(Search.search("100%")) == [wildcard.scientific_name]
      assert names(Search.search("test%author")) == []
      assert names(Search.search("l_ 1753")) == []
    end
  end

  describe "synonym_matches/2" do
    setup %{n: n} do
      bicolor =
        species_fixture(
          scientific_name: "bicolor#{n}",
          synonyms: [
            "platanoides#{n} Sudw.",
            %{"name" => "Q. discolor#{n}", "author" => "Michx."}
          ]
        )

      %{bicolor: bicolor}
    end

    test "names the first synonym the species was found through", %{n: n, bicolor: bicolor} do
      query = "PLATANOIDES#{n}"
      %{species: species} = Search.search(query)

      assert Search.synonym_matches(species, query) == %{
               bicolor.id => %{name: "platanoides#{n} Sudw.", author: nil}
             }
    end

    test "returns a synonym stored with its author apart", %{n: n, bicolor: bicolor} do
      query = "discolor#{n}"
      %{species: species} = Search.search(query)

      assert Search.synonym_matches(species, query) == %{
               bicolor.id => %{name: "Q. discolor#{n}", author: "Michx."}
             }
    end

    test "leaves out a species whose own name matched", %{bicolor: bicolor} do
      %{species: species} = Search.search(bicolor.scientific_name)

      assert bicolor.id in Enum.map(species, & &1.id)
      assert Search.synonym_matches(species, bicolor.scientific_name) == %{}
    end

    test "passes over a synonym string that joins several names", %{n: n} do
      joined =
        species_fixture(
          scientific_name: "×joined#{n}",
          is_hybrid: true,
          synonyms: ["ilex x petraea = koehnei#{n} Ambrosy", "koehnei#{n}a"]
        )

      query = "koehnei#{n}"
      %{species: species} = Search.search(query)

      assert Search.synonym_matches(species, query) == %{
               joined.id => %{name: "koehnei#{n}a", author: nil}
             }

      %{species: species} = Search.search("petraea = koehnei#{n}")
      assert joined.id in Enum.map(species, & &1.id)
      assert Search.synonym_matches(species, "petraea = koehnei#{n}") == %{}
    end

    test "leaves out a species found by a common name", %{n: n, alba: alba} do
      query = "white oak #{n}"
      %{species: species} = Search.search(query)

      assert alba.id in Enum.map(species, & &1.id)
      assert Search.synonym_matches(species, query) == %{}
    end
  end

  defp names(%{species: species}), do: Enum.map(species, & &1.scientific_name)
end
