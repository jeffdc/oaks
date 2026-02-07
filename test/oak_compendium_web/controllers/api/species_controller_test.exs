defmodule OakCompendiumWeb.API.SpeciesControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /api/v1/species" do
    test "returns paginated species list", %{conn: conn} do
      conn = get(conn, "/api/v1/species")

      assert %{"data" => data, "count" => count, "limit" => 50, "offset" => 0} =
               json_response(conn, 200)

      assert is_list(data)
      assert count == 5
      assert length(data) == 5
    end

    test "species have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/species")
      %{"data" => [species | _]} = json_response(conn, 200)

      assert Map.has_key?(species, "id")
      assert Map.has_key?(species, "scientific_name")
      assert Map.has_key?(species, "is_hybrid")
      assert Map.has_key?(species, "subgenus")
      assert Map.has_key?(species, "section")
    end

    test "respects limit parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/species?limit=2")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert length(data) == 2
      assert count == 5
    end

    test "respects offset parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/species?limit=2&offset=4")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert length(data) == 1
      assert count == 5
    end

    test "filters by subgenus", %{conn: conn} do
      conn = get(conn, "/api/v1/species?subgenus=Lobatae")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert count == 2
      assert Enum.all?(data, fn s -> s["subgenus"] == "Lobatae" end)
    end

    test "filters by hybrid status", %{conn: conn} do
      conn = get(conn, "/api/v1/species?hybrid=true")
      %{"data" => data, "count" => count} = json_response(conn, 200)
      assert count == 1
      assert Enum.all?(data, fn s -> s["is_hybrid"] == true end)
    end
  end

  describe "GET /api/v1/species/:name" do
    test "returns a species by name", %{conn: conn} do
      conn = get(conn, "/api/v1/species/alba")
      species = json_response(conn, 200)
      assert species["scientific_name"] == "alba"
      assert species["author"] == "L. 1753"
      assert species["is_hybrid"] == false
      assert species["subgenus"] == "Quercus"
    end

    test "returns 404 for unknown species", %{conn: conn} do
      conn = get(conn, "/api/v1/species/nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns hybrid species", %{conn: conn} do
      conn = get(conn, "/api/v1/species/%C3%97bebbiana")
      species = json_response(conn, 200)
      assert species["scientific_name"] == "×bebbiana"
      assert species["is_hybrid"] == true
      assert species["parent1"] == "alba"
      assert species["parent2"] == "macrocarpa"
    end

    test "JSON array fields are returned as arrays", %{conn: conn} do
      conn = get(conn, "/api/v1/species/alba")
      species = json_response(conn, 200)
      assert is_list(species["hybrids"])
      assert is_list(species["synonyms"])
    end
  end

  describe "GET /api/v1/species/:name/full" do
    test "returns species with source data", %{conn: conn} do
      conn = get(conn, "/api/v1/species/alba/full")
      species = json_response(conn, 200)
      assert species["scientific_name"] == "alba"
      assert is_list(species["sources"])
      assert length(species["sources"]) == 2
    end

    test "sources include expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/species/alba/full")
      %{"sources" => sources} = json_response(conn, 200)
      preferred = Enum.find(sources, & &1["is_preferred"])
      assert preferred["source_name"] == "Oaks of the World"
      assert preferred["local_names"] == ["white oak", "eastern white oak"]
      assert preferred["range"] == "Eastern North America; 0 to 1600 m"
    end

    test "returns 404 for unknown species", %{conn: conn} do
      conn = get(conn, "/api/v1/species/nonexistent/full")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "GET /api/v1/species/search" do
    test "searches by name substring", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search?q=alb")
      %{"data" => data} = json_response(conn, 200)
      assert data != []
      assert Enum.any?(data, fn s -> s["scientific_name"] == "alba" end)
    end

    test "search is case-insensitive", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search?q=RUBRA")
      %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, fn s -> s["scientific_name"] == "rubra" end)
    end

    test "returns 400 when q is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
