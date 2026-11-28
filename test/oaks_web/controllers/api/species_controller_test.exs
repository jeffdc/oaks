defmodule OaksWeb.API.SpeciesControllerTest do
  use OaksWeb.ConnCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Species

  setup do
    n = System.unique_integer([:positive])
    subgenus = taxon_fixture(name: "Subgenus#{n}", level: "subgenus")
    section = taxon_fixture(name: "Section#{n}", level: "section", parent_id: subgenus.id)

    alba =
      species_fixture(
        scientific_name: "alba#{n}",
        author: "L. 1753",
        taxon_id: section.id,
        synonyms: ["alba var. repanda"]
      )

    macrocarpa = species_fixture(scientific_name: "macrocarpa#{n}")

    bebbiana =
      hybrid_fixture(
        scientific_name: "×bebbiana#{n}",
        parent1_id: alba.id,
        parent2_id: macrocarpa.id,
        taxon_id: section.id
      )

    rubra = species_fixture(scientific_name: "rubra#{n}", taxon_id: subgenus.id)

    species_source_fixture(alba, source_fixture(name: "Oaks of the World #{n}"),
      is_preferred: true,
      local_names: ["white oak", "eastern white oak"],
      range: "Eastern North America; 0 to 1600 m"
    )

    species_source_fixture(alba, source_fixture())

    %{
      subgenus: subgenus.name,
      alba: alba,
      bebbiana: bebbiana,
      macrocarpa: macrocarpa,
      rubra: rubra,
      n: n
    }
  end

  describe "GET /api/v1/species" do
    test "returns paginated species list", %{conn: conn} do
      conn = get(conn, "/api/v1/species")

      assert %{"data" => data, "count" => count, "limit" => 50, "offset" => 0} =
               json_response(conn, 200)

      assert is_list(data)
      assert count == Species.count()
      assert length(data) == min(count, 50)
    end

    test "species have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/species")
      %{"data" => [species | _]} = json_response(conn, 200)

      assert Map.has_key?(species, "id")
      assert Map.has_key?(species, "scientific_name")
      assert Map.has_key?(species, "is_hybrid")
      assert Map.has_key?(species, "taxon_id")
      assert Map.has_key?(species, "parent1_id")
      assert Map.has_key?(species, "parent2_id")
    end

    test "respects limit parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/species?limit=2")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert length(data) == 2
      assert count == Species.count()
    end

    test "respects offset parameter", %{conn: conn, subgenus: subgenus} do
      conn = get(conn, "/api/v1/species?subgenus=#{subgenus}&limit=2&offset=2")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert length(data) == 1
      assert count == 3
    end

    test "filters by subgenus, including the species in its child taxa", %{
      conn: conn,
      subgenus: subgenus,
      alba: alba,
      bebbiana: bebbiana,
      rubra: rubra
    } do
      conn = get(conn, "/api/v1/species?subgenus=#{subgenus}")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert count == 3
      assert Enum.sort(Enum.map(data, & &1["id"])) == Enum.sort([alba.id, bebbiana.id, rubra.id])
    end

    test "filters by hybrid status", %{conn: conn, bebbiana: bebbiana} do
      conn = get(conn, "/api/v1/species?hybrid=true&limit=500")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert count == Species.count_hybrids()
      assert Enum.all?(data, fn s -> s["is_hybrid"] == true end)
      assert bebbiana.scientific_name in Enum.map(data, & &1["scientific_name"])
    end
  end

  describe "GET /api/v1/species/:name" do
    test "returns a species by name", %{conn: conn, alba: alba} do
      conn = get(conn, ~p"/api/v1/species/#{alba.scientific_name}")
      species = json_response(conn, 200)
      assert species["scientific_name"] == alba.scientific_name
      assert species["author"] == "L. 1753"
      assert species["is_hybrid"] == false
      assert species["taxon_id"] == alba.taxon_id
    end

    test "returns 404 for unknown species", %{conn: conn} do
      conn = get(conn, "/api/v1/species/nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "redirects a synonym with authorship to the accepted species", %{conn: conn, n: n} do
      species = species_fixture(synonyms: ["repanda#{n} Michx."])
      name = species.scientific_name

      conn = get(conn, ~p"/api/v1/species/repanda#{n}")
      assert %{"scientific_name" => ^name} = json_response(conn, 301)
      assert get_resp_header(conn, "location") == ["/api/v1/species/#{name}"]
    end

    test "returns hybrid species", %{
      conn: conn,
      alba: alba,
      bebbiana: bebbiana,
      macrocarpa: macrocarpa
    } do
      conn = get(conn, ~p"/api/v1/species/#{bebbiana.scientific_name}")
      species = json_response(conn, 200)
      assert species["scientific_name"] == bebbiana.scientific_name
      assert species["is_hybrid"] == true
      assert species["parent1_id"] == alba.id
      assert species["parent2_id"] == macrocarpa.id
    end

    test "JSON array fields are returned as arrays", %{conn: conn, alba: alba} do
      conn = get(conn, ~p"/api/v1/species/#{alba.scientific_name}")
      species = json_response(conn, 200)
      assert is_list(species["synonyms"])
      assert is_list(species["external_links"])
    end
  end

  describe "GET /api/v1/species/:name/full" do
    test "returns species with source data", %{conn: conn, alba: alba} do
      conn = get(conn, ~p"/api/v1/species/#{alba.scientific_name}/full")
      species = json_response(conn, 200)
      assert species["scientific_name"] == alba.scientific_name
      assert is_list(species["sources"])
      assert length(species["sources"]) == 2
    end

    test "sources include expected fields", %{conn: conn, alba: alba, n: n} do
      conn = get(conn, ~p"/api/v1/species/#{alba.scientific_name}/full")
      %{"sources" => sources} = json_response(conn, 200)
      preferred = Enum.find(sources, & &1["is_preferred"])
      assert preferred["source_name"] == "Oaks of the World #{n}"
      assert preferred["local_names"] == ["white oak", "eastern white oak"]
      assert preferred["range"] == "Eastern North America; 0 to 1600 m"
    end

    test "returns 404 for unknown species", %{conn: conn} do
      conn = get(conn, "/api/v1/species/nonexistent/full")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "GET /api/v1/species/search" do
    test "searches by name substring", %{conn: conn, alba: alba, n: n} do
      conn = get(conn, "/api/v1/species/search?q=lba#{n}")
      %{"data" => data} = json_response(conn, 200)
      assert Enum.map(data, & &1["scientific_name"]) == [alba.scientific_name]
    end

    test "search is case-insensitive", %{conn: conn, rubra: rubra} do
      conn = get(conn, "/api/v1/species/search?q=#{String.upcase(rubra.scientific_name)}")
      %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, fn s -> s["scientific_name"] == rubra.scientific_name end)
    end

    test "returns 400 when q is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
