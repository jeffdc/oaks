defmodule OakCompendium.SchemaTest do
  @moduledoc """
  Verifies that Ecto schemas can query the database correctly.
  Runs against the test database (structure.sql + test_seeds.sql).
  """
  use OakCompendium.DataCase

  alias OakCompendium.Repo
  alias OakCompendium.Species.Species
  alias OakCompendium.Taxonomy.Taxon
  alias OakCompendium.Sources.Source
  alias OakCompendium.Sources.SpeciesSource
  alias OakCompendium.Articles.Article
  alias OakCompendium.Import.Metadata

  describe "Species schema" do
    test "loads all seeded species" do
      species = Repo.all(Species)
      assert length(species) == 5
    end

    test "finds species by scientific name" do
      alba = Repo.get_by!(Species, scientific_name: "alba")
      assert alba.author == "L. 1753"
      assert alba.is_hybrid == false
      assert alba.subgenus == "Quercus"
      assert alba.section == "Quercus"
    end

    test "loads hybrid species" do
      hybrid = Repo.get_by!(Species, scientific_name: "×bebbiana")
      assert hybrid.is_hybrid == true
      assert hybrid.parent1 == "alba"
      assert hybrid.parent2 == "macrocarpa"
    end

    test "preloads species_sources association" do
      alba =
        Species
        |> Repo.get_by!(scientific_name: "alba")
        |> Repo.preload(:species_sources)

      assert length(alba.species_sources) == 2
    end
  end

  describe "Taxon schema" do
    test "loads all seeded taxa" do
      taxa = Repo.all(Taxon)
      assert length(taxa) == 5
    end

    test "finds taxon by name and level" do
      subgenus = Repo.get_by!(Taxon, name: "Quercus", level: "subgenus")
      assert subgenus.author == "(L.) Oerst."
      assert is_nil(subgenus.parent)
    end

    test "finds child taxon with parent" do
      section = Repo.get_by!(Taxon, name: "Quercus", level: "section")
      assert section.parent == "Quercus"
    end
  end

  describe "Source schema" do
    test "loads all seeded sources" do
      sources = Repo.all(Source)
      assert length(sources) == 3
    end

    test "finds source by name" do
      source = Repo.get_by!(Source, name: "Oaks of the World")
      assert source.source_type == "website"
      assert source.url == "https://oaksoftheworld.fr"
    end

    test "preloads species_sources association" do
      source =
        Source
        |> Repo.get_by!(name: "Oaks of the World")
        |> Repo.preload(:species_sources)

      assert length(source.species_sources) == 2
    end
  end

  describe "SpeciesSource schema" do
    test "loads all seeded species_sources" do
      ss = Repo.all(SpeciesSource)
      assert length(ss) == 3
    end

    test "preloads species and source associations" do
      ss =
        SpeciesSource
        |> Repo.get!(1)
        |> Repo.preload([:species, :source])

      assert ss.species.scientific_name == "alba"
      assert ss.source.name == "Oaks of the World"
      assert ss.is_preferred == true
      assert ss.local_names == ~s(["white oak","eastern white oak"])
    end
  end

  describe "Article schema" do
    test "loads seeded articles" do
      articles = Repo.all(Article)
      assert length(articles) == 2

      published = Enum.find(articles, &(&1.slug == "getting-started"))
      assert published.is_published == true
      assert published.author == "Jeff"

      draft = Enum.find(articles, &(&1.slug == "advanced-taxonomy-draft"))
      assert draft.is_published == false
    end
  end

  describe "Import.Metadata schema" do
    test "loads seeded metadata" do
      all = Repo.all(Metadata)
      assert length(all) == 2
    end

    test "finds metadata by key" do
      meta = Repo.get!(Metadata, "last_import_date")
      assert meta.value == "2025-01-01"
    end
  end
end
