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
    # Synonym epithets carry the suffix `n` so seeded synonyms can't match.
    setup do
      n = System.unique_integer([:positive])

      %{
        n: n,
        alba: species_fixture(scientific_name: "alba#{n}", synonyms: ["alba#{n} var. repanda"]),
        rubra: species_fixture(scientific_name: "rubra#{n}")
      }
    end

    test "finds species with matching synonym", %{n: n, alba: alba} do
      assert Species.find_synonym("alba#{n} var. repanda").id == alba.id
    end

    test "returns nil when no synonym match" do
      assert Species.find_synonym("nonexistent synonym") == nil
    end

    test "matches synonyms that carry authorship", %{n: n, rubra: rubra} do
      set_synonyms(rubra, [
        "handeliana#{n} A.Camus",
        "argentata#{n} (Korth.) Oerst. 1867",
        "shumardii#{n} var. acerifolia E.J.Palmer 1927"
      ])

      assert Species.find_synonym("handeliana#{n}").id == rubra.id
      assert Species.find_synonym("argentata#{n}").id == rubra.id
      assert Species.find_synonym("shumardii#{n} var. acerifolia").id == rubra.id
    end

    test "does not match a name followed by a rank or another epithet", %{n: n, rubra: rubra} do
      set_synonyms(rubra, [
        "reticulata#{n} var. retifolia Liebm. 1869",
        "falcata#{n} pagodifolia"
      ])

      assert Species.find_synonym("reticulata#{n}") == nil
      assert Species.find_synonym("falcata#{n}") == nil
    end

    test "ignores case, extra whitespace, Quercus prefix, and hybrid sign", %{n: n, rubra: rubra} do
      set_synonyms(rubra, ["Quercus  Borealis#{n} Michx.f.", "×  fernaldii#{n} Trel."])

      assert Species.find_synonym("borealis#{n}").id == rubra.id
      assert Species.find_synonym("×fernaldii#{n}").id == rubra.id
      assert Species.find_synonym("× fernaldii#{n}").id == rubra.id
    end

    test "matches structured name/author entries", %{n: n, rubra: rubra} do
      set_synonyms(rubra, [%{"name" => "maxima#{n}", "author" => "(Marshall) Ashe"}])

      assert Species.find_synonym("maxima#{n}").id == rubra.id
    end

    test "prefers an exact match over an author-suffixed one", %{n: n, alba: alba, rubra: rubra} do
      set_synonyms(alba, ["repanda#{n} Michx."])
      set_synonyms(rubra, ["repanda#{n}"])

      assert Species.find_synonym("repanda#{n}").id == rubra.id
    end

    test "treats LIKE wildcards in the lookup literally", %{n: n} do
      assert Species.find_synonym("%") == nil
      assert Species.find_synonym("alba#{n} var. repand_") == nil
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

  describe "placement/1" do
    defp steps(species), do: Enum.map(Species.placement(species), &{&1.level, &1.name})

    test "lists a species' stored ranks, outermost first, skipping the ones it lacks" do
      species =
        species_fixture(subgenus: "Quercus", section: "Lobatae", complex: unique("coccinea"))

      assert [{"subgenus", "Quercus"}, {"section", "Lobatae"}, {"complex", _}] = steps(species)
    end

    test "keeps a hybrid's stored ranks" do
      hybrid = hybrid_fixture(subgenus: "Quercus", section: "Quercus")
      assert steps(hybrid) == [{"subgenus", "Quercus"}, {"section", "Quercus"}]
    end

    test "places a hybrid with no ranks of its own where both parents sit" do
      a = species_fixture(subgenus: "Quercus", section: "Quercus", subsection: "Albae")
      b = species_fixture(subgenus: "Quercus", section: "Quercus", subsection: "Stellatae")
      c = species_fixture(subgenus: "Cerris", section: "Cerris")

      shared = hybrid_fixture(parent1: a.scientific_name, parent2: b.scientific_name)
      apart = hybrid_fixture(parent1: a.scientific_name, parent2: c.scientific_name)
      unknown = hybrid_fixture(parent1: a.scientific_name, parent2: unique("missing"))

      assert steps(shared) == [{"subgenus", "Quercus"}, {"section", "Quercus"}]
      assert steps(apart) == []
      assert steps(unknown) == []
    end

    test "places a variety under its species, after the species' ranks" do
      species = species_fixture(subgenus: "Cerris")

      variety =
        species_fixture(scientific_name: "#{species.scientific_name} kingii", subgenus: "Cerris")

      assert [_, %{level: "species", name: name, hybrid: false}] = Species.placement(variety)
      assert name == species.scientific_name
    end

    test "places a named hybrid's subspecies under it, and never a formula under a word of it" do
      named = hybrid_fixture()
      nothosubspecies = hybrid_fixture(scientific_name: "#{named.scientific_name} montserratii")

      assert [%{level: "species", hybrid: true, name: name}] = Species.placement(nothosubspecies)
      assert name == named.scientific_name

      a = species_fixture()
      formula = hybrid_fixture(scientific_name: "#{a.scientific_name} × parvula")
      assert Species.placement(formula) == []
    end
  end

  defp set_synonyms(species, synonyms) do
    species
    |> Ecto.Changeset.change(synonyms: Jason.encode!(synonyms))
    |> Oaks.Repo.update!()
  end

  # -- The data display contract (docs/species-photos-plan.md, Phase 4) --

  # A source row as get_species_full/1 preloads it, without the database.
  defp row(source_id, name, attrs \\ []) do
    struct(
      %Oaks.Sources.SpeciesSource{
        id: System.unique_integer([:positive]),
        source_id: source_id,
        source: %Oaks.Sources.Source{id: source_id, name: name}
      },
      attrs
    )
  end

  defp names(rows), do: Enum.map(rows, & &1.source.name)

  describe "ordered_sources/1" do
    test "puts the preferred row first, then Oak Compendium, Oaks of the World and the rest by name" do
      rows = [
        row(10, "zeta"),
        row(2, "Oaks of the World"),
        row(11, "Alpha"),
        row(3, "Oak Compendium"),
        row(12, "beta", is_preferred: true)
      ]

      assert names(Species.ordered_sources(rows)) ==
               ["beta", "Oak Compendium", "Oaks of the World", "Alpha", "zeta"]
    end

    test "keeps Oak Compendium ahead of Oaks of the World when neither is preferred, and is stable on ties" do
      rows = [
        row(21, "Same"),
        row(2, "Oaks of the World"),
        row(20, "Same"),
        row(3, "Oak Compendium")
      ]

      ordered = Species.ordered_sources(rows)

      assert names(ordered) == ["Oak Compendium", "Oaks of the World", "Same", "Same"]
      assert Enum.map(ordered, & &1.source_id) |> Enum.take(-2) == [20, 21]
      assert Species.ordered_sources(Enum.reverse(rows)) == ordered
    end
  end

  describe "default_source/1 and has_text?/1" do
    test "opens on the first row with any text, skipping blank and whitespace-only values" do
      blank = row(3, "Oak Compendium", leaves: "  ", local_names: ~s(["", " "]))
      texty = row(2, "Oaks of the World", range: "Missouri;")

      refute Species.has_text?(blank)
      assert Species.has_text?(texty)
      assert Species.default_source([blank, texty]) == texty
    end

    test "counts a common name alone as text" do
      assert Species.has_text?(row(4, "Sibley", local_names: ~s(["Shumard Oak"])))
    end

    test "falls back to the first row when none has text, and nil for none" do
      first = row(3, "Oak Compendium")
      assert Species.default_source([first, row(2, "Oaks of the World")]) == first
      assert Species.default_source([]) == nil
    end
  end

  describe "common_name/1" do
    test "takes the first nonempty name of the first row in order that has one" do
      oc = row(3, "Oak Compendium", local_names: ~s(["  "]))
      ootw = row(2, "Oaks of the World", local_names: ~s(["", "Shumard's oak", "Other"]))
      sibley = row(4, "Sibley", local_names: ~s(["Shumard Oak"]))

      assert Species.common_name([oc, ootw, sibley]) == {"Shumard's oak", ootw}
      assert Species.common_names(ootw) == ["Shumard's oak", "Other"]
    end

    test "is nil when no row has a name" do
      assert Species.common_name([row(3, "Oak Compendium"), row(2, "Oaks of the World")]) == nil
    end
  end

  describe "covered?/1" do
    test "is true only when the Oak Compendium row has text" do
      refute Species.covered?([
               row(3, "Oak Compendium", miscellaneous: " "),
               row(2, "Oaks of the World", leaves: "x")
             ])

      refute Species.covered?([row(2, "Oaks of the World", leaves: "x")])
      assert Species.covered?([row(3, "Oak Compendium", twigs: "green")])
    end
  end

  describe "hybrids_with_other_parent/1" do
    test "pairs each hybrid with its parent that isn't this species" do
      parent = species_fixture()
      named = hybrid_fixture(parent1: "Quercus " <> parent.scientific_name, parent2: "rubra")
      lone = hybrid_fixture(parent1: parent.scientific_name)
      unknown = unique("× nowhere")

      parent =
        parent
        |> Ecto.Changeset.change(
          hybrids: Jason.encode!([named.scientific_name, lone.scientific_name, unknown])
        )
        |> Oaks.Repo.update!()

      assert Species.hybrids_with_other_parent(parent) == [
               %{name: named.scientific_name, other: "rubra"},
               %{name: lone.scientific_name, other: nil},
               %{name: unknown, other: nil}
             ]
    end
  end

  describe "siblings/1" do
    test "lists the species stored at its last rank, without hybrids or varieties" do
      complex = unique("complex")
      a = species_fixture(scientific_name: unique("a"), complex: complex)
      b = species_fixture(scientific_name: unique("b"), complex: complex)
      _variety = species_fixture(scientific_name: a.scientific_name <> " minor", complex: complex)
      hybrid = hybrid_fixture(complex: complex)

      assert %{level: "complex", name: ^complex, names: names} = Species.siblings(a)
      assert names == Enum.sort([a.scientific_name, b.scientific_name])
      assert Species.siblings(hybrid).names == names
    end

    test "lists a variety's sister varieties under its species" do
      species = species_fixture()
      v1 = species_fixture(scientific_name: species.scientific_name <> " one")
      v2 = species_fixture(scientific_name: species.scientific_name <> " two")

      assert %{level: "species", names: names} = Species.siblings(v1)
      assert names == [v1.scientific_name, v2.scientific_name]
    end

    test "is nil with no group or no one else in it" do
      assert Species.siblings(species_fixture()) == nil
      assert Species.siblings(species_fixture(complex: unique("alone"))) == nil
    end
  end
end
