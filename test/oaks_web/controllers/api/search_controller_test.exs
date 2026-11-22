defmodule OaksWeb.API.SearchControllerTest do
  use OaksWeb.ConnCase

  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  describe "GET /api/v1/search" do
    test "returns results grouped by type", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q=quercus")
      result = json_response(conn, 200)
      assert Map.has_key?(result, "species")
      assert Map.has_key?(result, "taxa")
      assert Map.has_key?(result, "sources")
    end

    test "finds species by name", %{conn: conn} do
      %{scientific_name: name} = species_fixture()

      conn = get(conn, "/api/v1/search?q=#{name}")
      %{"species" => species} = json_response(conn, 200)
      assert Enum.any?(species, fn s -> s["scientific_name"] == name end)
    end

    test "finds taxa by name", %{conn: conn} do
      %{name: name} = taxon_fixture()

      conn = get(conn, "/api/v1/search?q=#{String.downcase(name)}")
      %{"taxa" => taxa} = json_response(conn, 200)
      assert Enum.any?(taxa, fn t -> t["name"] == name end)
    end

    test "returns 400 when q is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/search")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
