defmodule Oaks.TaxonomyTest do
  @moduledoc """
  Tests for the Taxonomy context module.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use Oaks.DataCase

  alias Oaks.Taxonomy

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

  describe "delete_taxon/1" do
    test "refuses while species or child taxa use the taxon" do
      section = Taxonomy.get_taxon_by_id(2)

      assert {:error, {:in_use, %{species: 3, children: 1}}} = Taxonomy.delete_taxon(section)
      assert Taxonomy.get_taxon_by_id(2)
    end

    test "deletes an unused taxon" do
      {:ok, taxon} =
        Taxonomy.create_taxon(%{name: "Unused", level: "complex", parent: "Stellatae"})

      assert {:ok, _} = Taxonomy.delete_taxon(taxon)
      refute Taxonomy.get_taxon_by_id(taxon.id)
    end
  end

  describe "update_taxon/2" do
    test "renaming a section updates its species and child subsections" do
      {:ok, _} = Taxonomy.update_taxon(Taxonomy.get_taxon_by_id(2), %{"name" => "Albae"})

      assert Oaks.Species.get_species_by_name("alba").section == "Albae"
      assert Oaks.Species.get_species_by_name("stellata").section == "Albae"
      assert Oaks.Species.get_species_by_name("alba").subgenus == "Quercus"
      assert Taxonomy.get_taxon_by_id(5).parent == "Albae"
      # The subgenus of the same name is untouched.
      assert Taxonomy.get_taxon_by_id(1).name == "Quercus"
      assert Taxonomy.get_taxon_by_id(2).parent == "Quercus"
    end

    test "renaming a section carries complexes placed directly under it" do
      {:ok, complex} =
        Taxonomy.create_taxon(%{name: "robur", level: "complex", parent: "Lobatae"})

      {:ok, _} = Taxonomy.update_taxon(Taxonomy.get_taxon_by_id(4), %{"name" => "Rubrae"})

      assert Taxonomy.get_taxon_by_id(complex.id).parent == "Rubrae"
      assert Oaks.Species.get_species_by_name("rubra").section == "Rubrae"
    end

    test "rename collisions return a changeset error and change nothing" do
      {:error, changeset} =
        Taxonomy.update_taxon(Taxonomy.get_taxon_by_id(4), %{"name" => "Quercus"})

      assert changeset.errors != []
      assert Oaks.Species.get_species_by_name("rubra").section == "Lobatae"
    end

    test "ignores level changes" do
      {:ok, taxon} = Taxonomy.update_taxon(Taxonomy.get_taxon_by_id(5), %{"level" => "complex"})
      assert taxon.level == "subsection"
    end

    test "stamps content_updated_at only when content changes" do
      {:ok, taxon} = Taxonomy.update_taxon(Taxonomy.get_taxon_by_id(5), %{"author" => "Trel."})
      assert taxon.content_updated_at == nil

      {:ok, taxon} = Taxonomy.update_taxon(taxon, %{"content" => "New text"})
      assert taxon.content_updated_at == Date.to_iso8601(Date.utc_today())
    end
  end

  describe "complexes placed directly under a section" do
    setup do
      {:ok, complex} =
        Taxonomy.create_taxon(%{name: "velutina-group", level: "complex", parent: "Lobatae"})

      Oaks.Species.get_species_by_name("velutina")
      |> Ecto.Changeset.change(complex: "velutina-group")
      |> Oaks.Repo.update!()

      %{complex: complex}
    end

    test "appear as children of the section", %{complex: complex} do
      children = Taxonomy.get_children(Taxonomy.get_taxon("section", "Lobatae"))
      assert complex.id in Enum.map(children, & &1.id)
    end

    test "resolve as a path segment under the section" do
      assert {:ok, [_, _, %{level: "complex", name: "velutina-group"}]} =
               Taxonomy.resolve_path(["Lobatae", "Lobatae", "velutina-group"])
    end

    test "own their species instead of the section" do
      complex_species = Taxonomy.get_species_in_taxon(["Lobatae", "Lobatae", "velutina-group"])
      section_species = Taxonomy.get_species_in_taxon(["Lobatae", "Lobatae"])

      assert Enum.map(complex_species, & &1.scientific_name) == ["velutina"]
      refute "velutina" in Enum.map(section_species, & &1.scientific_name)
      assert "rubra" in Enum.map(section_species, & &1.scientific_name)
    end

    test "search links to them through the section" do
      %{taxa: taxa} = Oaks.Search.search("velutina-group")
      assert [%{path: ["Lobatae", "Lobatae", "velutina-group"]}] = taxa
    end
  end

  describe "resolve_path/1" do
    test "rejects a segment that isn't a child of the previous one" do
      assert Taxonomy.resolve_path(["Lobatae", "Quercus"]) == :error
      assert Taxonomy.resolve_path(["Quercus", "Quercus", "Missing"]) == :error
    end
  end
end
