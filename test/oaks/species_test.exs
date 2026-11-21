defmodule Oaks.SpeciesTest do
  @moduledoc """
  Tests for the Species context module.
  """
  use Oaks.DataCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Species

  defp unique(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  describe "list_all_species/1" do
    setup do
      subgenus = unique("Subgenus")
      section = unique("Section")
      other_subgenus = unique("Subgenus")

      %{
        subgenus: subgenus,
        section: section,
        other_subgenus: other_subgenus,
        alba:
          species_fixture(scientific_name: unique("zalba"), subgenus: subgenus, section: section),
        stellata:
          species_fixture(
            scientific_name: unique("zstellata"),
            subgenus: subgenus,
            section: section
          ),
        rubra: species_fixture(scientific_name: unique("zrubra"), subgenus: other_subgenus)
      }
    end

    test "returns all species ordered by name", ctx do
      names = Enum.map(Species.list_all_species(), & &1.scientific_name)
      assert length(names) == Species.count()
      assert names == Enum.sort(names)
      assert ctx.alba.scientific_name in names
    end

    test "filters by subgenus", ctx do
      species = Species.list_all_species(%{"subgenus" => ctx.subgenus})
      assert Enum.map(species, & &1.id) == Enum.map([ctx.alba, ctx.stellata], & &1.id)
    end

    test "filters by section", ctx do
      species = Species.list_all_species(%{"section" => ctx.section})
      assert length(species) == 2
      assert Enum.all?(species, &(&1.section == ctx.section))
    end

    test "filters by search term", ctx do
      assert [found] = Species.list_all_species(%{"search" => ctx.alba.scientific_name})
      assert found.id == ctx.alba.id
    end

    test "search is case-insensitive", ctx do
      query = String.upcase(ctx.rubra.scientific_name)
      assert [found] = Species.list_all_species(%{"search" => query})
      assert found.id == ctx.rubra.id
    end

    test "combines search and taxonomy filters", ctx do
      species = Species.list_all_species(%{"search" => "z", "subgenus" => ctx.subgenus})
      ids = Enum.map(species, & &1.id)
      assert ctx.alba.id in ids
      assert ctx.stellata.id in ids
      refute ctx.rubra.id in ids
    end

    test "returns empty list when no matches" do
      species = Species.list_all_species(%{"search" => "zzzznonexistent"})
      assert species == []
    end
  end

  describe "distinct_subgenera/0" do
    test "returns unique subgenus values sorted" do
      [first, second] = Enum.sort([unique("Subgenus"), unique("Subgenus")])
      species_fixture(subgenus: second)
      species_fixture(subgenus: first)
      species_fixture(subgenus: first)

      subgenera = Species.distinct_subgenera()
      assert subgenera == Enum.uniq(subgenera)
      assert subgenera == Enum.sort(subgenera)
      assert Enum.filter(subgenera, &(&1 in [first, second])) == [first, second]
    end
  end

  describe "distinct_sections/0" do
    test "returns unique section values sorted" do
      [first, second] = Enum.sort([unique("Section"), unique("Section")])
      species_fixture(section: second)
      species_fixture(section: first)
      species_fixture(section: first)

      sections = Species.distinct_sections()
      assert sections == Enum.uniq(sections)
      assert sections == Enum.sort(sections)
      assert Enum.filter(sections, &(&1 in [first, second])) == [first, second]
    end
  end

  describe "get_species_by_name/1" do
    test "returns species when found" do
      created = species_fixture(author: "L. 1753")
      species = Species.get_species_by_name(created.scientific_name)
      assert species.id == created.id
      assert species.author == "L. 1753"
    end

    test "returns nil when not found" do
      assert Species.get_species_by_name("nonexistent") == nil
    end
  end

  describe "get_species_full/1" do
    setup do
      species = species_fixture()
      species_source_fixture(species, source_fixture(), is_preferred: false)
      preferred = source_fixture()
      species_source_fixture(species, preferred, is_preferred: true)
      %{species: species, preferred: preferred}
    end

    test "returns species with preloaded sources", %{species: species, preferred: preferred} do
      full = Species.get_species_full(species.scientific_name)
      assert full.id == species.id
      assert length(full.species_sources) == 2

      found = Enum.find(full.species_sources, & &1.is_preferred)
      assert found.source.name == preferred.name
    end

    test "preferred source comes first", %{species: species} do
      [first | _] = Species.get_species_full(species.scientific_name).species_sources
      assert first.is_preferred == true
    end

    test "returns nil when species not found" do
      assert Species.get_species_full("nonexistent") == nil
    end
  end

  describe "create_species/1" do
    test "creates species with valid attrs" do
      name = unique_species_name()
      attrs = %{scientific_name: name, is_hybrid: false, author: "Muenchh."}
      assert {:ok, species} = Species.create_species(attrs)
      assert species.scientific_name == name
      assert species.author == "Muenchh."
      refute species.is_hybrid
    end

    test "fails with duplicate scientific_name" do
      attrs = %{scientific_name: species_fixture().scientific_name, is_hybrid: false}
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
      attrs = %{
        scientific_name: unique_species_name(),
        is_hybrid: false,
        conservation_status: "VU"
      }

      assert {:ok, species} = Species.create_species(attrs)
      assert species.conservation_status == "VU"
    end
  end

  describe "update_species/2" do
    test "updates species with valid attrs" do
      species = species_fixture()
      assert {:ok, updated} = Species.update_species(species, %{author: "Linnaeus"})
      assert updated.author == "Linnaeus"
      assert updated.scientific_name == species.scientific_name
    end

    test "fails with invalid attrs" do
      species = species_fixture()
      assert {:error, changeset} = Species.update_species(species, %{scientific_name: ""})
      assert %{scientific_name: [_]} = errors_on(changeset)
    end
  end

  describe "delete_species/1" do
    test "deletes species" do
      species = species_fixture()
      assert {:ok, _} = Species.delete_species(species)
      assert Species.get_species_by_name(species.scientific_name) == nil
    end

    test "cascades to species_sources" do
      species = species_fixture()
      link = species_source_fixture(species, source_fixture())

      assert {:ok, _} = Species.delete_species(species)
      assert Species.get_species_by_name(species.scientific_name) == nil
      assert Oaks.Repo.get(Oaks.Sources.SpeciesSource, link.id) == nil
    end
  end

  describe "change_species/2" do
    test "returns a changeset" do
      changeset = Species.change_species(species_fixture())
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "find_synonym/1" do
    setup do
      %{
        alba: species_fixture(scientific_name: unique("alba"), synonyms: ["alba var. repanda"]),
        rubra: species_fixture(scientific_name: unique("rubra"))
      }
    end

    test "finds species with matching synonym", %{alba: alba} do
      assert Species.find_synonym("alba var. repanda").id == alba.id
    end

    test "returns nil when no synonym match" do
      assert Species.find_synonym("nonexistent synonym") == nil
    end

    test "matches synonyms that carry authorship", %{rubra: rubra} do
      set_synonyms(rubra, [
        "handeliana A.Camus",
        "argentata (Korth.) Oerst. 1867",
        "shumardii var. acerifolia E.J.Palmer 1927"
      ])

      assert Species.find_synonym("handeliana").id == rubra.id
      assert Species.find_synonym("argentata").id == rubra.id
      assert Species.find_synonym("shumardii var. acerifolia").id == rubra.id
    end

    test "does not match a name followed by a rank or another epithet", %{rubra: rubra} do
      set_synonyms(rubra, ["reticulata var. retifolia Liebm. 1869", "falcata pagodifolia"])

      assert Species.find_synonym("reticulata") == nil
      assert Species.find_synonym("falcata") == nil
    end

    test "ignores case, extra whitespace, Quercus prefix, and hybrid sign", %{rubra: rubra} do
      set_synonyms(rubra, ["Quercus  Borealis Michx.f.", "×  fernaldii Trel."])

      assert Species.find_synonym("borealis").id == rubra.id
      assert Species.find_synonym("×fernaldii").id == rubra.id
      assert Species.find_synonym("× fernaldii").id == rubra.id
    end

    test "matches structured name/author entries", %{rubra: rubra} do
      set_synonyms(rubra, [%{"name" => "maxima", "author" => "(Marshall) Ashe"}])

      assert Species.find_synonym("maxima").id == rubra.id
    end

    test "prefers an exact match over an author-suffixed one", %{alba: alba, rubra: rubra} do
      set_synonyms(alba, ["repanda Michx."])
      set_synonyms(rubra, ["repanda"])

      assert Species.find_synonym("repanda").id == rubra.id
    end

    test "treats LIKE wildcards in the lookup literally" do
      assert Species.find_synonym("%") == nil
      assert Species.find_synonym("alba var. repand_") == nil
    end

    test "returns nil for a blank name" do
      assert Species.find_synonym("  ") == nil
    end
  end

  describe "change_species/2 hybrid flag" do
    test "requires the hybrid flag for names containing ×" do
      changeset = Species.change_species(%Oaks.Species.Species{}, %{scientific_name: "× foo"})
      assert changeset.errors[:is_hybrid]

      changeset =
        Species.change_species(%Oaks.Species.Species{}, %{
          scientific_name: "× foo",
          is_hybrid: true
        })

      refute changeset.errors[:is_hybrid]
    end
  end

  defp set_synonyms(species, synonyms) do
    species
    |> Ecto.Changeset.change(synonyms: Jason.encode!(synonyms))
    |> Oaks.Repo.update!()
  end
end
