defmodule OakCompendium.TaxonomyTest do
  @moduledoc """
  Tests for the Taxonomy context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendium.DataCase

  alias OakCompendium.Taxonomy

  describe "list_taxa_by_level/1" do
    test "returns subgenera" do
      taxa = Taxonomy.list_taxa_by_level("subgenus")
      names = Enum.map(taxa, & &1.name)
      assert length(taxa) == 2
      assert "Quercus" in names
      assert "Lobatae" in names
    end

    test "returns sections" do
      taxa = Taxonomy.list_taxa_by_level("section")
      assert length(taxa) == 2
      assert Enum.all?(taxa, &(&1.level == "section"))
    end

    test "returns subsections" do
      taxa = Taxonomy.list_taxa_by_level("subsection")
      assert length(taxa) == 1
      assert hd(taxa).name == "Stellatae"
    end

    test "ignores invalid level and returns all taxa" do
      taxa = Taxonomy.list_taxa_by_level("invalid")
      assert length(taxa) == 5
    end
  end

  describe "list_taxa_with_counts/1" do
    test "subgenera have correct species counts" do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "subgenus"})
      quercus = Enum.find(taxa, &(&1.name == "Quercus"))
      lobatae = Enum.find(taxa, &(&1.name == "Lobatae"))

      # alba, stellata, bebbiana in subgenus Quercus
      assert quercus.species_count == 3
      # rubra, velutina in subgenus Lobatae
      assert lobatae.species_count == 2
    end

    test "sections have correct species counts" do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "section"})
      quercus_sec = Enum.find(taxa, &(&1.name == "Quercus"))

      # alba, stellata, bebbiana in section Quercus
      assert quercus_sec.species_count == 3
    end

    test "subsections have correct species counts" do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "subsection"})
      stellatae = Enum.find(taxa, &(&1.name == "Stellatae"))

      # only stellata in subsection Stellatae
      assert stellatae.species_count == 1
    end

    test "filters by parent" do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "section", "parent" => "Quercus"})
      assert length(taxa) == 1
      assert hd(taxa).name == "Quercus"
    end
  end

  describe "get_children/1" do
    test "returns sections for subgenus Quercus" do
      taxon = Taxonomy.get_taxon("subgenus", "Quercus")
      children = Taxonomy.get_children(taxon)

      assert length(children) == 1
      assert hd(children).name == "Quercus"
      assert hd(children).level == "section"
      assert hd(children).species_count == 3
    end

    test "returns subsections for section Quercus" do
      taxon = Taxonomy.get_taxon("section", "Quercus")
      children = Taxonomy.get_children(taxon)

      assert length(children) == 1
      assert hd(children).name == "Stellatae"
      assert hd(children).level == "subsection"
    end

    test "returns empty for subsection (no complexes in test data)" do
      taxon = Taxonomy.get_taxon("subsection", "Stellatae")
      assert Taxonomy.get_children(taxon) == []
    end

    test "returns sections for subgenus Lobatae" do
      taxon = Taxonomy.get_taxon("subgenus", "Lobatae")
      children = Taxonomy.get_children(taxon)

      assert length(children) == 1
      assert hd(children).name == "Lobatae"
      assert hd(children).species_count == 2
    end
  end

  describe "get_species_in_taxon/1" do
    test "genus level returns species without subgenus" do
      # All test species have subgenera, so empty
      assert Taxonomy.get_species_in_taxon([]) == []
    end

    test "subgenus Quercus returns species without section" do
      # All Quercus species have a section, so empty
      assert Taxonomy.get_species_in_taxon(["Quercus"]) == []
    end

    test "section Quercus returns species without subsection" do
      species = Taxonomy.get_species_in_taxon(["Quercus", "Quercus"])
      names = Enum.map(species, & &1.scientific_name)

      # alba and bebbiana have no subsection; stellata has subsection Stellatae
      assert length(species) == 2
      assert "alba" in names
      assert "\u00D7bebbiana" in names
      refute "stellata" in names
    end

    test "subsection Stellatae returns its species" do
      species = Taxonomy.get_species_in_taxon(["Quercus", "Quercus", "Stellatae"])

      assert length(species) == 1
      assert hd(species).scientific_name == "stellata"
    end

    test "section Lobatae returns its species" do
      species = Taxonomy.get_species_in_taxon(["Lobatae", "Lobatae"])
      names = Enum.map(species, & &1.scientific_name)

      assert length(species) == 2
      assert "rubra" in names
      assert "velutina" in names
    end

    test "returns empty for non-matching path" do
      assert Taxonomy.get_species_in_taxon(["Nonexistent"]) == []
    end

    test "species are ordered by name" do
      species = Taxonomy.get_species_in_taxon(["Lobatae", "Lobatae"])
      names = Enum.map(species, & &1.scientific_name)
      assert names == Enum.sort(names)
    end
  end
end
