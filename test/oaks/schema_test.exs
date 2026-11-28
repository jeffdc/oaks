defmodule Oaks.SchemaTest do
  @moduledoc """
  Verifies that each Ecto schema round-trips through the database: rows
  inserted through fixtures read back with the same fields and associations.
  """
  use Oaks.DataCase

  import Oaks.ArticlesFixtures
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Articles.Article
  alias Oaks.Import.Metadata
  alias Oaks.Repo
  alias Oaks.Sources.Source
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Species.Species
  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  describe "Species schema" do
    test "reads back a species by scientific name" do
      section = taxon_fixture(level: "section", parent_id: taxon_fixture(level: "subgenus").id)
      created = species_fixture(author: "L. 1753", taxon_id: section.id)

      loaded = Repo.get_by!(Species, scientific_name: created.scientific_name)
      assert loaded.id == created.id
      assert loaded.author == "L. 1753"
      assert loaded.is_hybrid == false
      assert loaded.taxon_id == section.id
    end

    test "reads back a hybrid with its parents" do
      alba = species_fixture()
      macrocarpa = species_fixture()
      created = hybrid_fixture(parent1_id: alba.id, parent2_id: macrocarpa.id)

      hybrid = Repo.get!(Species, created.id) |> Repo.preload([:parent1, :parent2])
      assert hybrid.is_hybrid == true
      assert hybrid.parent1.scientific_name == alba.scientific_name
      assert hybrid.parent2.scientific_name == macrocarpa.scientific_name
    end

    test "preloads species_sources association" do
      species = species_fixture()
      species_source_fixture(species, source_fixture())
      species_source_fixture(species, source_fixture())

      loaded = Species |> Repo.get!(species.id) |> Repo.preload(:species_sources)
      assert length(loaded.species_sources) == 2
    end
  end

  describe "Taxon schema" do
    test "reads back a taxon by name and level" do
      created = taxon_fixture(author: "(L.) Oerst.")

      subgenus = Repo.get_by!(Taxon, name: created.name, level: "subgenus")
      assert subgenus.id == created.id
      assert subgenus.author == "(L.) Oerst."
      assert subgenus.parent_id == Taxonomy.get_genus().id
    end

    test "reads back a child taxon with its parent" do
      %{subgenus: subgenus, section: section} = taxon_tree_fixture()

      assert Repo.get_by!(Taxon, name: section.name, level: "section").parent_id == subgenus.id
    end
  end

  describe "Source schema" do
    test "reads back a source by name" do
      created = source_fixture(url: "https://oaksoftheworld.fr")

      source = Repo.get_by!(Source, name: created.name)
      assert source.source_type == "website"
      assert source.url == "https://oaksoftheworld.fr"
    end

    test "preloads species_sources association" do
      source = source_fixture()
      species_source_fixture(species_fixture(), source)
      species_source_fixture(species_fixture(), source)

      loaded = Source |> Repo.get!(source.id) |> Repo.preload(:species_sources)
      assert length(loaded.species_sources) == 2
    end
  end

  describe "SpeciesSource schema" do
    test "preloads species and source associations" do
      species = species_fixture()
      source = source_fixture()

      created =
        species_source_fixture(species, source,
          is_preferred: true,
          local_names: ["white oak", "eastern white oak"]
        )

      ss = SpeciesSource |> Repo.get!(created.id) |> Repo.preload([:species, :source])

      assert ss.species.scientific_name == species.scientific_name
      assert ss.source.name == source.name
      assert ss.is_preferred == true
      assert ss.local_names == ~s(["white oak","eastern white oak"])
    end
  end

  describe "Article schema" do
    test "reads back published and draft articles" do
      published = article_fixture(tags: ["guide"])
      draft = article_fixture(is_published: false)

      loaded = Repo.get!(Article, published.id)
      assert loaded.slug == published.slug
      assert loaded.is_published == true
      assert loaded.author == "Jeff"
      assert loaded.tags == ~s(["guide"])

      assert Repo.get!(Article, draft.id).is_published == false
    end
  end

  describe "Import.Metadata schema" do
    test "reads back metadata by key" do
      key = "last_import_date_#{System.unique_integer([:positive])}"

      %Metadata{}
      |> Metadata.changeset(%{key: key, value: "2025-01-01"})
      |> Repo.insert!()

      assert Repo.get!(Metadata, key).value == "2025-01-01"
    end
  end
end
