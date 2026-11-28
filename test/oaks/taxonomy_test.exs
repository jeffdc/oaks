defmodule Oaks.TaxonomyTest do
  @moduledoc """
  Tests for the Taxonomy context module.
  """
  use Oaks.DataCase

  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Species
  alias Oaks.Taxonomy

  # Two subgenera, each with a section of the same name (as in Quercus
  # subgenus Quercus, section Quercus), and a subsection under the first:
  #
  #   q / q        alba, ×bebbiana
  #   q / q / st   stellata
  #   l / l        rubra, velutina
  #
  # Names carry a unique suffix so they can't clash with seeded taxa.
  setup do
    n = System.unique_integer([:positive])
    q = "Quercus#{n}"
    l = "Lobatae#{n}"
    st = "Stellatae#{n}"

    subgenus_q = taxon_fixture(name: q, level: "subgenus")
    section_q = taxon_fixture(name: q, level: "section", parent_id: subgenus_q.id)
    subgenus_l = taxon_fixture(name: l, level: "subgenus")
    section_l = taxon_fixture(name: l, level: "section", parent_id: subgenus_l.id)
    subsection = taxon_fixture(name: st, level: "subsection", parent_id: section_q.id)

    %{
      q: q,
      l: l,
      st: st,
      subgenus_q: subgenus_q,
      section_q: section_q,
      subgenus_l: subgenus_l,
      section_l: section_l,
      subsection: subsection,
      alba: species_fixture(scientific_name: "alba#{n}", taxon_id: section_q.id),
      stellata: species_fixture(scientific_name: "stellata#{n}", taxon_id: subsection.id),
      bebbiana: hybrid_fixture(scientific_name: "×bebbiana#{n}", taxon_id: section_q.id),
      rubra: species_fixture(scientific_name: "rubra#{n}", taxon_id: section_l.id),
      velutina: species_fixture(scientific_name: "velutina#{n}", taxon_id: section_l.id)
    }
  end

  defp names(species), do: Enum.map(species, & &1.scientific_name)
  defp ids(records), do: Enum.map(records, & &1.id)

  describe "get_genus/0" do
    test "returns the one genus row" do
      genus = Taxonomy.get_genus()
      assert genus.level == "genus"
      assert genus.name == "Quercus"
      assert is_nil(genus.parent_id)
      assert Repo.aggregate(Taxonomy.Taxon, :count) |> is_integer()
    end
  end

  describe "list_taxa_by_level/1" do
    test "returns subgenera", ctx do
      taxa = Taxonomy.list_taxa_by_level("subgenus")
      assert Enum.all?(taxa, &(&1.level == "subgenus"))
      assert ctx.subgenus_q.id in ids(taxa)
      assert ctx.subgenus_l.id in ids(taxa)
    end

    test "returns sections", ctx do
      taxa = Taxonomy.list_taxa_by_level("section")
      assert Enum.all?(taxa, &(&1.level == "section"))
      assert ctx.section_q.id in ids(taxa)
      refute ctx.subgenus_q.id in ids(taxa)
    end

    test "returns subsections", ctx do
      taxa = Taxonomy.list_taxa_by_level("subsection")
      assert Enum.all?(taxa, &(&1.level == "subsection"))
      assert ctx.subsection.id in ids(taxa)
    end

    test "ignores invalid level and returns all taxa" do
      taxa = Taxonomy.list_taxa_by_level("invalid")
      assert length(taxa) == Taxonomy.count()
    end
  end

  describe "list_taxa_with_counts/1" do
    test "subgenera have their subtree's species counts", ctx do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "subgenus"})

      # alba, stellata (subsection) and bebbiana in q; rubra, velutina in l
      assert Enum.find(taxa, &(&1.id == ctx.subgenus_q.id)).species_count == 3
      assert Enum.find(taxa, &(&1.id == ctx.subgenus_l.id)).species_count == 2
    end

    test "sections have their subtree's species counts", ctx do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "section"})
      assert Enum.find(taxa, &(&1.id == ctx.section_q.id)).species_count == 3
    end

    test "subsections have their own species counts", ctx do
      taxa = Taxonomy.list_taxa_with_counts(%{"level" => "subsection"})
      assert Enum.find(taxa, &(&1.id == ctx.subsection.id)).species_count == 1
    end

    test "filters by parent", ctx do
      taxa =
        Taxonomy.list_taxa_with_counts(%{"level" => "section", "parent_id" => ctx.subgenus_q.id})

      assert ids(taxa) == [ctx.section_q.id]
    end
  end

  describe "get_children/1" do
    test "returns sections for a subgenus", ctx do
      assert [child] = Taxonomy.get_children(ctx.subgenus_q)
      assert child.id == ctx.section_q.id
      assert child.level == "section"
      assert child.species_count == 3
    end

    test "returns subsections for a section", ctx do
      assert [child] = Taxonomy.get_children(ctx.section_q)
      assert child.id == ctx.subsection.id
      assert child.level == "subsection"
    end

    test "returns empty for a subsection with no complexes", ctx do
      assert Taxonomy.get_children(ctx.subsection) == []
    end

    test "returns sections for the other subgenus", ctx do
      assert [child] = Taxonomy.get_children(ctx.subgenus_l)
      assert child.id == ctx.section_l.id
      assert child.species_count == 2
    end

    test "the genus's children are subgenera", ctx do
      children = Taxonomy.get_children(Taxonomy.get_genus())
      assert ctx.subgenus_q.id in ids(children)
      assert ctx.subgenus_l.id in ids(children)
    end
  end

  describe "get_species_in_taxon/1" do
    test "genus level returns species placed in the genus or with no taxon", ctx do
      loose = species_fixture()
      in_genus = species_fixture(taxon_id: Taxonomy.get_genus().id)

      species = Taxonomy.get_species_in_taxon([])
      assert loose.id in ids(species)
      assert in_genus.id in ids(species)
      refute ctx.alba.id in ids(species)
    end

    test "subgenus returns species placed directly at it", ctx do
      loose = species_fixture(taxon_id: ctx.subgenus_q.id)

      assert ids(Taxonomy.get_species_in_taxon([ctx.q])) == [loose.id]
    end

    test "section returns species placed directly at it", ctx do
      species = Taxonomy.get_species_in_taxon([ctx.q, ctx.q])

      # alba and bebbiana sit at the section; stellata is in the subsection
      assert names(species) == [ctx.alba.scientific_name, ctx.bebbiana.scientific_name]
    end

    test "subsection returns its species", ctx do
      assert ids(Taxonomy.get_species_in_taxon([ctx.q, ctx.q, ctx.st])) == [ctx.stellata.id]
    end

    test "section returns all its species when it has no subsections", ctx do
      species = Taxonomy.get_species_in_taxon([ctx.l, ctx.l])
      assert names(species) == [ctx.rubra.scientific_name, ctx.velutina.scientific_name]
    end

    test "returns empty for non-matching path" do
      assert Taxonomy.get_species_in_taxon(["Nonexistent"]) == []
    end

    test "species are ordered by name", ctx do
      species_fixture(scientific_name: "aaa#{ctx.l}", taxon_id: ctx.section_l.id)

      names = names(Taxonomy.get_species_in_taxon([ctx.l, ctx.l]))
      assert names == Enum.sort(names)
    end
  end

  describe "delete_taxon/1" do
    test "refuses while species or child taxa use the taxon", ctx do
      assert {:error, {:in_use, %{species: 3, children: 1}}} =
               Taxonomy.delete_taxon(ctx.section_q)

      assert Taxonomy.get_taxon_by_id(ctx.section_q.id)
    end

    test "deletes an unused taxon", ctx do
      {:ok, taxon} =
        Taxonomy.create_taxon(%{name: "Unused", level: "complex", parent_id: ctx.subsection.id})

      assert {:ok, _} = Taxonomy.delete_taxon(taxon)
      refute Taxonomy.get_taxon_by_id(taxon.id)
    end
  end

  describe "update_taxon/2" do
    test "renaming a section changes only its row", ctx do
      new_name = "Albae#{ctx.q}"
      {:ok, _} = Taxonomy.update_taxon(ctx.section_q, %{"name" => new_name})

      assert Taxonomy.get_taxon_by_id(ctx.section_q.id).name == new_name
      # Species and children link by key, so their rows are untouched.
      assert Species.get_species_by_name(ctx.alba.scientific_name).taxon_id == ctx.section_q.id

      assert Species.get_species_by_name(ctx.stellata.scientific_name).taxon_id ==
               ctx.subsection.id

      assert Taxonomy.get_taxon_by_id(ctx.subsection.id).parent_id == ctx.section_q.id
      # The subgenus of the same name is untouched.
      assert Taxonomy.get_taxon_by_id(ctx.subgenus_q.id).name == ctx.q
      assert Taxonomy.get_taxon_by_id(ctx.section_q.id).parent_id == ctx.subgenus_q.id
    end

    test "rename collisions return a changeset error and change nothing", ctx do
      {:error, changeset} = Taxonomy.update_taxon(ctx.section_l, %{"name" => ctx.q})

      assert changeset.errors != []
      assert Taxonomy.get_taxon_by_id(ctx.section_l.id).name == ctx.l
    end

    test "ignores level changes", ctx do
      {:ok, taxon} = Taxonomy.update_taxon(ctx.subsection, %{"level" => "complex"})
      assert taxon.level == "subsection"
    end

    test "stamps content_updated_at only when content changes", ctx do
      {:ok, taxon} = Taxonomy.update_taxon(ctx.subsection, %{"author" => "Trel."})
      assert taxon.content_updated_at == nil

      {:ok, taxon} = Taxonomy.update_taxon(taxon, %{"content" => "New text"})
      assert taxon.content_updated_at == Date.to_iso8601(Date.utc_today())
    end
  end

  describe "the rank rule" do
    test "requires a parent below the genus", _ctx do
      assert {:error, changeset} = Taxonomy.create_taxon(%{name: "Loose", level: "section"})
      assert changeset.errors[:parent_id]
    end

    test "refuses a parent that does not rank above the child", ctx do
      assert {:error, changeset} =
               Taxonomy.create_taxon(%{
                 name: "Backwards",
                 level: "subgenus",
                 parent_id: ctx.section_q.id
               })

      assert changeset.errors[:parent_id]
      refute Taxonomy.get_taxon("subgenus", "Backwards")
    end

    test "allows any higher rank, not only the one directly above", ctx do
      assert {:ok, taxon} =
               Taxonomy.create_taxon(%{
                 name: "Skipped#{ctx.l}",
                 level: "complex",
                 parent_id: ctx.subgenus_l.id
               })

      assert taxon.parent_id == ctx.subgenus_l.id
    end

    test "the genus has no parent, and a genus with one is refused" do
      assert {:error, changeset} =
               Taxonomy.create_taxon(%{
                 name: "Another",
                 level: "genus",
                 parent_id: Taxonomy.get_genus().id
               })

      assert changeset.errors[:parent_id]
    end

    test "update refuses a parent that does not rank above", ctx do
      assert {:error, changeset} =
               Taxonomy.update_taxon(ctx.subgenus_q, %{"parent_id" => ctx.section_q.id})

      assert changeset.errors[:parent_id]
      assert Taxonomy.get_taxon_by_id(ctx.subgenus_q.id).parent_id == Taxonomy.get_genus().id
    end
  end

  describe "complexes placed directly under a section" do
    setup ctx do
      group = "velutina-group#{ctx.l}"
      complex = taxon_fixture(name: group, level: "complex", parent_id: ctx.section_l.id)

      ctx.velutina
      |> Ecto.Changeset.change(taxon_id: complex.id)
      |> Oaks.Repo.update!()

      %{complex: complex, group: group}
    end

    test "appear as children of the section", %{complex: complex, section_l: section_l} do
      children = Taxonomy.get_children(section_l)
      assert complex.id in ids(children)
    end

    test "resolve as a path segment under the section", %{l: l, group: group} do
      assert {:ok, [_, _, %{level: "complex", name: ^group}]} =
               Taxonomy.resolve_path([l, l, group])
    end

    test "own their species instead of the section", ctx do
      complex_species = Taxonomy.get_species_in_taxon([ctx.l, ctx.l, ctx.group])
      section_species = Taxonomy.get_species_in_taxon([ctx.l, ctx.l])

      assert ids(complex_species) == [ctx.velutina.id]
      refute ctx.velutina.id in ids(section_species)
      assert ctx.rubra.id in ids(section_species)
    end

    test "search links to them through the section", %{l: l, group: group} do
      %{taxa: taxa} = Oaks.Search.search(group)
      assert [%{path: [^l, ^l, ^group]}] = taxa
    end
  end

  describe "resolve_path/1" do
    test "rejects a segment that isn't a child of the previous one", %{q: q, l: l} do
      assert Taxonomy.resolve_path([l, q]) == :error
      assert Taxonomy.resolve_path([q, q, "Missing"]) == :error
    end

    test "an empty path resolves to no taxa" do
      assert Taxonomy.resolve_path([]) == {:ok, []}
    end
  end
end
